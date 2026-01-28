import { Client as McpClient } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';
import { DEFAULT_MODEL } from './constants.js';

async function main() {
  const urlStr = process.env.MCP_URL || 'http://localhost:3333/mcp';
  const url = new URL(urlStr);

  const prompt = process.env.TEST_PROMPT || 'Write a haiku.';
  const model = process.env.TEST_MODEL || DEFAULT_MODEL;
  const temperature = Number(process.env.TEST_TEMPERATURE ?? 0.7);

  console.log(`Connecting to MCP server: ${url.href}`);
  const transport = new StreamableHTTPClientTransport(url);
  const client = new McpClient(
    { name: 'test-client', version: '1.0.0' },
    { capabilities: {} }
  );

  await client.connect(transport);

  const tools = await client.listTools();
  console.log('Tools:', tools.tools.map(t => t.name));

  const res = await client.callTool({
    name: 'gemini_generateText',
    arguments: {
      prompt,
      model,
      temperature,
    }
  });

  const text =
    (res as any)?.content?.find?.((c: any) => c?.type === 'text')?.text ??
    JSON.stringify(res);

  console.log('=== Test Configuration ===');
  console.log(`Prompt: ${prompt}`);
  console.log(`Model: ${model}`);
  console.log(`Temperature: ${temperature}`);
  console.log('=== Tool Result ===');
  console.log(text);
  console.log('=========================');

  await client.close();
}

main().catch((err) => {
  console.error('TEST FAILED:', err?.stack || err);
  process.exit(1);
});
