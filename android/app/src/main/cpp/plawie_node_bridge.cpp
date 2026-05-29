#include <jni.h>
#include <android/log.h>

#include <atomic>
#include <string>
#include <thread>
#include <vector>

#define LOG_TAG "PlawieNodeBridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace {
std::atomic<bool> g_running{false};
std::atomic<int> g_last_exit_code{-999};

std::vector<std::string> copy_java_args(JNIEnv* env, jobjectArray java_args) {
    std::vector<std::string> copied;
    if (java_args == nullptr) return copied;

    const jsize count = env->GetArrayLength(java_args);
    copied.reserve(static_cast<size_t>(count));

    for (jsize i = 0; i < count; ++i) {
        auto item = static_cast<jstring>(env->GetObjectArrayElement(java_args, i));
        if (item == nullptr) {
            copied.emplace_back("");
            continue;
        }

        const char* raw = env->GetStringUTFChars(item, nullptr);
        copied.emplace_back(raw == nullptr ? "" : raw);
        if (raw != nullptr) env->ReleaseStringUTFChars(item, raw);
        env->DeleteLocalRef(item);
    }

    return copied;
}
}  // namespace

#if PLAWIE_NODE_HAS_LIBNODE
namespace node {
int Start(int argc, char* argv[]);
}
#endif

extern "C" JNIEXPORT jint JNICALL
Java_com_nxg_openclawproot_NativeNodeBridge_startNode(
    JNIEnv* env,
    jobject,
    jobjectArray java_args) {
#if !PLAWIE_NODE_HAS_LIBNODE
    LOGE("libnode.so was not present when libplawie_node_bridge.so was built");
    return -2;
#else
    bool expected = false;
    if (!g_running.compare_exchange_strong(expected, true)) {
        LOGI("Node start ignored; runtime already running");
        return 1;
    }

    std::vector<std::string> args = copy_java_args(env, java_args);
    if (args.empty()) {
        g_running.store(false);
        LOGE("Node start failed; no argv supplied");
        return -3;
    }

    g_last_exit_code.store(-998);
    std::thread([args = std::move(args)]() mutable {
        std::vector<char*> argv;
        argv.reserve(args.size());
        for (std::string& arg : args) {
            argv.push_back(arg.data());
        }

        LOGI("Calling node::Start with %zu argv entries", argv.size());
        const int code = node::Start(static_cast<int>(argv.size()), argv.data());
        g_last_exit_code.store(code);
        g_running.store(false);
        LOGI("node::Start returned %d", code);
    }).detach();

    return 0;
#endif
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_nxg_openclawproot_NativeNodeBridge_isRunning(JNIEnv*, jobject) {
    return g_running.load() ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_nxg_openclawproot_NativeNodeBridge_lastExitCode(JNIEnv*, jobject) {
    return g_last_exit_code.load();
}
