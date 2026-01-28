import 'dotenv/config';
import express from 'express';
import { z } from 'zod';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { GoogleGenAI } from '@google/genai';
import { DEFAULT_MODEL } from './constants.js';

const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

const server = new McpServer({ name: 'gemini-mcp', version: '0.1.0' });

const Input = z.object({
  prompt: z.string().min(1),
  model: z.string().default(DEFAULT_MODEL),
  temperature: z.number().min(0).max(2).default(1),
});

type InputType = z.infer<typeof Input>;

server.registerTool(
  'gemini_generateText',
  {
    title: 'Gemini: generate text',
    description: `Call Google Gemini models via the Google Gen AI SDK. The default model is the latest reasoning model (${DEFAULT_MODEL}), so you typically do not need to specify a model.`,
    // SDK 1.20.x requires ZodRawShape, so pass Input.shape instead of the full Zod object
    inputSchema: Input.shape,
  },
  async (args: InputType) => {
    const { prompt, model, temperature } = args;
    if (!process.env.GEMINI_API_KEY) throw new Error('GEMINI_API_KEY is not set');

    const response = await ai.models.generateContent({
      model,
      contents: prompt,
      config: {
        temperature,
        tools: [{ googleSearch: {} }],
       },
    });
    const parts = (response as any).candidates?.[0]?.content?.parts || [];
    const text = parts
      .filter((part: any) => part.text)
      .map((part: any) => part.text)
      .join('');

    return {
      content: [{ type: 'text', text }],
      structuredContent: { model, temperature, text },
    };
  }
);

const app = express();
app.use(express.json());

// Health check endpoint for Cloud Run and warmup
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

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
app.listen(port, '0.0.0.0', () => {
  console.log(`Gemini MCP listening on http://0.0.0.0:${port}/mcp`);
});
