enum SkillExecutionRuntime {
  python,
  node,
  shell,
  mcp,
  http,
  unknown,
}

enum SkillExecutionMode {
  pythonToolsClass,
  pythonScript,
  nodeModule,
  shellRecipe,
  mcpServer,
  httpEndpoint,
  unknown,
}

class SkillExecutionAction {
  final String label;
  final String method;
  final Map<String, String> args;

  const SkillExecutionAction({
    required this.label,
    required this.method,
    required this.args,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'method': method,
        'args': args,
      };
}

class SkillExecutionMethodDescriptor {
  final String name;
  final String description;
  final Map<String, String> parameters;
  final List<String> requiredParameters;

  const SkillExecutionMethodDescriptor({
    required this.name,
    this.description = '',
    this.parameters = const <String, String>{},
    this.requiredParameters = const <String>[],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description.isNotEmpty) 'description': description,
        if (parameters.isNotEmpty) 'parameters': parameters,
        if (requiredParameters.isNotEmpty)
          'requiredParameters': requiredParameters,
      };
}

class SkillDependencyDescriptor {
  final List<String> runtimes;
  final List<String> bins;
  final List<String> pythonPackages;
  final List<String> nodePackages;
  final List<String> env;
  final List<String> config;
  final List<String> plugins;

  const SkillDependencyDescriptor({
    this.runtimes = const <String>[],
    this.bins = const <String>[],
    this.pythonPackages = const <String>[],
    this.nodePackages = const <String>[],
    this.env = const <String>[],
    this.config = const <String>[],
    this.plugins = const <String>[],
  });

  Map<String, dynamic> toJson() => {
        if (runtimes.isNotEmpty) 'runtimes': runtimes,
        if (bins.isNotEmpty) 'bins': bins,
        if (pythonPackages.isNotEmpty) 'pythonPackages': pythonPackages,
        if (nodePackages.isNotEmpty) 'nodePackages': nodePackages,
        if (env.isNotEmpty) 'env': env,
        if (config.isNotEmpty) 'config': config,
        if (plugins.isNotEmpty) 'plugins': plugins,
      };
}

class SkillExecutionDescriptor {
  final String skillId;
  final String rootPath;
  final String source;
  final SkillExecutionRuntime runtime;
  final SkillExecutionMode mode;
  final String entrypoint;
  final String? className;
  final SkillDependencyDescriptor dependencies;
  final List<SkillExecutionMethodDescriptor> methods;

  const SkillExecutionDescriptor({
    required this.skillId,
    required this.rootPath,
    required this.source,
    required this.runtime,
    required this.mode,
    required this.entrypoint,
    this.className,
    this.dependencies = const SkillDependencyDescriptor(),
    this.methods = const <SkillExecutionMethodDescriptor>[],
  });

  Map<String, dynamic> toJson() => {
        'skillId': skillId,
        'rootPath': rootPath,
        'source': source,
        'runtime': runtime.name,
        'mode': mode.name,
        'entrypoint': entrypoint,
        if (className != null && className!.isNotEmpty) 'className': className,
        'dependencies': dependencies.toJson(),
        if (methods.isNotEmpty)
          'methods': methods.map((method) => method.toJson()).toList(),
      };
}
