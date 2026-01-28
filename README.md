# Gemini MCP Server

An MCP (Model Context Protocol) server that provides access to Google Gemini AI models.

## Quick Start

1. Install dependencies:
```bash
npm install
```

2. Create a `.env` file with your Gemini API key:
```env
GEMINI_API_KEY=your_api_key_here
```

3. Start the server:
```bash
npm run dev
```

The server will run at `http://localhost:3333/mcp`

## Available Tool

### `gemini_generateText`

Generate text using Google Gemini models.

**Parameters:**
- `prompt` (string, required): The text prompt
- `model` (string, optional): Gemini model to use (default: `gemini-2.5-pro`)
- `temperature` (number, optional): Temperature for generation, 0-2 (default: 1)

**Returns:**
- `text`: Generated text response
- `model`: Model used
- `temperature`: Temperature setting used

## Usage Example

```typescript
import { Client as McpClient } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';

const transport = new StreamableHTTPClientTransport(
  new URL('http://localhost:3333/mcp')
);

const client = new McpClient(
  { name: 'my-client', version: '1.0.0' },
  { capabilities: {} }
);

await client.connect(transport);

const result = await client.callTool({
  name: 'gemini_generateText',
  arguments: {
    prompt: 'Explain AI in simple terms',
    model: 'gemini-2.5-pro',
    temperature: 0.7
  }
});

console.log(result);
await client.close();
```

## Testing

Run the included test client (requires server to be running):
```bash
npm test
```

## Configuration

Environment variables:
- `GEMINI_API_KEY` (required): Your Google Gemini API key
- `PORT` (optional): Server port (default: 3333)

## Deployment

Deploy to Google Cloud Run with automated scripts:

```bash
# 0. Prerequisites (one-time, via GCP Console)
#    - Create GCP project
#    - Link billing account
#    - Run: gcloud auth login

# 1. Setup GCP (one-time)
./bin/setup-gcp.sh \
  --project-id=my-project \
  --github-user=your-username \
  --github-repo=gemini-mcp

# 2. Set GitHub Secrets (follow script output)

# 3. Deploy
git push origin main
```

For detailed deployment instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).

## License

ISC
