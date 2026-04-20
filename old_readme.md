i tried doing this in my last commit but failed how do i diagonize whats wrong?? can u do research online and also look at my current code. We wanted to fix this::

""""""Cloud Ollama auth — full native flow:

Info banner: "Free · No download needed · Powered by Ollama · Requires a free ollama.com account"
Auth status card: green Icons.verified when signed in, amber Icons.lock_outline + "tap to connect" when not — tapping triggers _launchOllamaSignin()
Refresh button on the card → _checkOllamaSignin() on demand
didChangeAppLifecycleState(resumed) auto-refreshes signin status when user returns from browser OAuth
_launchOllamaSignin(): runs ollama signin in PRoot, captures the OAuth URL, opens it in system browser via url_launcher, falls back to clipboard copy, falls back to raw output dialog
Unauthenticated model selection now shows a proper bottom sheet with "Sign in to Ollama" button instead of a snackbar
Gateway sendMessage(): reason=auth / surface_error in stream=error frames → clean actionable message instead of raw gateway error string"""""


WE NEED A SEEMLESS OLLAMA INTEGRATION USING THE TECHNIQUES FROM TEIR OFFICIAL DOCS UNDER openclaw PAGES GO ONLINE AND READ AND PLAN FIRST - WHAT IS WRONG?

ALSO, IF I HAD AN APP ALREADY INSTALLED AND UPDATED IT, THEN I TRY USE OLLAMA CLOUD FREE, IT THROW AN ERRO "NOT AUTHORIZED" DESPITE ME MAKING THE CODE FIXES I DID AND COMMITED 1 COMMIT AGO (CHECK ALSO)

THIS APP IS SUPPOSED TO ALLOW LOCAL LLM SERVER FOR GATEWAY, NDK FORLOCAL CHATS, AND CLOUD SPLIT INTO GEMINI, OPENAI ETC & THE OTHER HALF IN FOCUS NOW OLLAMA CLOUD MODELS. 
- This has to be according to docs
- You have to read my entire gateway and other files Chat Page, Local LLM Page etc related to this upgrade
- You have to respect the current core mechanism we have to switch models seemlessly without breaking connection 
- Users have to get the seemless experience as per the Ollama official openclaw docs whih state that we can dynamically create accounts fr users inside PROOT. instead of asking them to bring API keys we create and auto save etc.
- UI changes will be relevant to all pages mentioned, but dont forget the Setup flow page also where users configure model providers after installing the app - Ollama Cloud there should be clearly stated as free and auto configured when u hit the chat page selecting it from the drop down menu...

We need meticuloud investigation, aduting, and planning