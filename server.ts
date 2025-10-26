import 'dotenv/config';
import express from 'express';
import { z } from 'zod';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { GoogleGenAI } from '@google/genai';

const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

const server = new McpServer({ name: 'gemini-mcp', version: '0.1.0' });

const Input = z.object({
  prompt: z.string().min(1),
  model: z.string().default('gemini-2.5-pro'),
  temperature: z.number().min(0).max(2).default(1),
});

type InputType = z.infer<typeof Input>;

server.registerTool(
  'gemini.generateText',
  {
    title: 'Gemini: generate text',
    description: 'Call Google Gemini models via the Google Gen AI SDK.',
    // SDK 1.20.x requires ZodRawShape, so pass Input.shape instead of the full Zod object
    inputSchema: Input.shape,
  },
  async (args: InputType) => {
    const { prompt, model, temperature } = args;
    if (!process.env.GEMINI_API_KEY) throw new Error('GEMINI_API_KEY is not set');

    const response = await ai.models.generateContent({
      model,
      contents: prompt,
      config: { temperature },
    });
    const text = response.text || '';

    return {
      content: [{ type: 'text', text }],
      structuredContent: { model, temperature, text },
    };
  }
);

const app = express();
app.use(express.json());
app.post('/mcp', async (req, res) => {
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined,
    enableJsonResponse: true,
  });
  res.on('close', () => transport.close());
  await server.connect(transport);
  await transport.handleRequest(req, res, req.body);
});

const port = parseInt(process.env.PORT || '3333', 10);
app.listen(port, () => {
  console.log(`Gemini MCP listening on http://localhost:${port}/mcp`);
});
