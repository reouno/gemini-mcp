// test.ts
import { Client as McpClient } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';

async function main() {
  const urlStr = process.env.MCP_URL || 'http://localhost:3333/mcp';
  const url = new URL(urlStr); // ← ここがポイント（string → URL）

  const prompt = process.env.TEST_PROMPT || '俳句を一つ作って。';
  const model = process.env.TEST_MODEL || 'gemini-2.5-pro';
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
    name: 'gemini.generateText',
    arguments: {
      prompt,
      model,
      temperature,
    }
  });

  const text =
    (res as any)?.content?.find?.((c: any) => c?.type === 'text')?.text ??
    JSON.stringify(res);

  console.log('=== Tool Result ===');
  console.log(text);
  console.log('===================');

  await client.close();
}

main().catch((err) => {
  console.error('TEST FAILED:', err?.stack || err);
  process.exit(1);
});
