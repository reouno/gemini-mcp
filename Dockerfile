# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files and install all dependencies (including dev)
COPY package*.json ./
RUN npm ci

# Copy source files and build
COPY tsconfig.json ./
COPY server.ts ./
RUN npm run build

# Production stage
FROM node:20-alpine

WORKDIR /app

# Copy package files and install production dependencies only
COPY package*.json ./
RUN npm ci --only=production

# Copy built application from builder
COPY --from=builder /app/dist ./dist

# Expose port (Cloud Run uses PORT env variable)
EXPOSE 8080

# Note: Cloud Run automatically sets PORT environment variable to 8080
# No need to set ENV PORT here as it will be overridden

# Start the server directly with node (faster than npm start)
CMD ["node", "dist/server.js"]
