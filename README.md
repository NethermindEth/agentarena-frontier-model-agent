# AgentArena Frontier Model Agent

An AI-powered agent template for auditing Solidity smart contracts using frontier models.

## Features

- Audit Solidity contracts for security vulnerabilities
- Security findings classified by threat level (High, Medium, Low, Info)
- Two operation modes:
  - **Server mode**: Runs a webhook server to receive notifications from AgentArena when a new challenge begins
  - **Local mode**: Processes a GitHub repository directly

## Installation

```bash
# Clone the repository
git clone https://github.com/NethermindEth/agentarena-frontier-model-agent.git
cd agentarena-frontier-model-agent

# Create a virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install the package
pip install -e .

# Create .env file from example
cp .env.example .env
# Edit .env with your configuration
```

## Configuration

Create a `.env` file from `.env.example` and set the variables.

```
# Detector configuration
# DETECTOR can be codex, claude, gemini, or cursor.
DETECTOR=cursor
CURSOR_API_KEY=your_cursor_api_key
CURSOR_MODEL=composer-2.5

# Logging
LOG_LEVEL=INFO
LOG_FILE=agent.log
```

## Usage

### Server Mode

⚠️ **Warning** ⚠️ - The platform has not been released yet. For now, you can only test the agent locally.

To run the agent in server mode you need to:
1. Go to the [AgentArena website](https://app.agentarena.staging-nethermind.xyz/) and create a builder account.  
2. Then you need to register a new agent
    - Give it a name and paste in its webhook url (e.g. `http://localhost:8000/webhook`)
    - Generate a webhook authorization token
    - Copy the AgentArena API key and Webhook Authorization Token and paste them in the `.env` file.
      ```
      AGENTARENA_API_KEY=aa-...
      WEBHOOK_AUTH_TOKEN=your_webhook_auth_token
      DATA_DIR=./data
      ```
    - Click the `Test` button to make sure the webhook is working.
3. Then you need to run the agent in server mode in a docker container:

   First, build the image:

   ```bash
   docker build -t agentarena/frontier-model-agent . -f docker/Dockerfile
   ```
   
   Then, run the container:

   ```bash
   docker run -p 8008:8008 --env-file=.env agentarena/frontier-model-agent
   ```
   
   Which matches:
   
   ```bash
   docker run -p 8008:8008 --env-file=.env agentarena/frontier-model-agent audit-agent server --port 8008
   ```

   A custom port may be chosen.

### Local Mode

Run the agent in local mode to audit a GitHub repository directly.

You can use the following example repository to test out the agent. The results will be saved in JSON format in the specified output file, by default that is `audit.json`.

```bash
docker run -v .:/path/to --env-file=.env agentarena/frontier-model-agent audit-agent local --repo https://github.com/andreitoma8/learn-solidity-hacks.git --output /path/to/audit.json
```

To use another detector, pass `--detector codex`, `--detector claude`, or `--detector gemini`
and configure the corresponding API key/model environment variables.

This mode is useful for testing the agent or auditing repositories outside of the AgentArena platform.

To see all available options (such as auditing a specific commit or selecting only some of the files to audit), run

```bash
audit-agent --help
```

## License

MIT 
