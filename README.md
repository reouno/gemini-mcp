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

### `gemini.generateText`

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
  name: 'gemini.generateText',
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

## License

ISC
