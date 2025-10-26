# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an MCP (Model Context Protocol) server that exposes Google Gemini AI models through a standardized interface. The server runs as an HTTP endpoint and allows MCP clients to call Gemini models for text generation.

## Development Commands

**Start the server:**
```bash
npm run dev
```
Server starts on port 3333 by default (configurable via `PORT` environment variable).

**Run the test client:**
```bash
npm test
```
This executes `test.ts` which connects to the running server and calls the `gemini.generateText` tool.

**Note:** The server must be running (via `npm run dev`) before running tests.

## Environment Configuration

Required environment variable:
- `GEMINI_API_KEY` - Google Gemini API key (configured in `.env`)

Optional server configuration:
- `PORT` - Server port (default: 3333)

Optional test configuration:
- `MCP_URL` - MCP server URL (default: http://localhost:3333/mcp)
- `TEST_PROMPT` - Prompt to test with (default: '俳句を一つ作って。')
- `TEST_MODEL` - Gemini model to use (default: 'gemini-2.5-pro')
- `TEST_TEMPERATURE` - Temperature setting (default: 0.7)

## Architecture

**Server Architecture** (`server.ts`):
- Express server with a single POST endpoint at `/mcp`
- Uses MCP SDK's `StreamableHTTPServerTransport` for HTTP-based MCP communication
- Registers one tool: `gemini.generateText`
- Tool uses Google Gen AI SDK to call Gemini models with configurable parameters (model, temperature)
- Response extraction handles multiple Google Gen AI SDK version differences using defensive type checking

**Tool Schema** (`gemini.generateText`):
- Input validated with Zod schema
- Parameters: `prompt` (string, required), `model` (string, default: 'gemini-2.5-pro'), `temperature` (number 0-2, default: 1)
- Returns structured content with model, temperature, and generated text

**Test Client** (`test.ts`):
- Uses MCP SDK's `StreamableHTTPClientTransport` to connect to the server
- Lists available tools and calls `gemini.generateText`
- Demonstrates the full client-server MCP interaction pattern

## Key Implementation Details

- The server uses SDK 1.20.x which requires passing `Input.shape` (ZodRawShape) to `inputSchema` instead of the full Zod object
- Type handling for Google Gen AI SDK is defensive (uses `any` casts) to handle version differences
- Text extraction from Gemini responses handles multiple possible response formats for compatibility
- Transport cleanup is tied to Express response close event to prevent resource leaks
