# Between Us AI backend

This dependency-free development server lets the iOS Simulator use genuine model-generated scenarios without placing an API key in the mobile app.

## Run

```bash
cd Backend
OPENAI_API_KEY="your-project-key" node server.mjs
```

The iOS app defaults to `http://127.0.0.1:8787`. Open either person, select **AI**, confirm the backend URL, and generate a conversation.

Check the server before opening the app:

```bash
curl http://127.0.0.1:8787/health
```

For production, deploy the same contract behind HTTPS and add user authentication, rate limiting, request logging that excludes relationship content, abuse controls, and budget limits.
