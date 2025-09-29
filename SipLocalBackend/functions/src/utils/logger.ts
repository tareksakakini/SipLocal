import * as functions from "firebase-functions";

export type LogLevel = "debug" | "info" | "warn" | "error";

export interface LogContext {
  handler?: string;
  requestId?: string;
  merchantId?: string;
  userId?: string;
  [key: string]: unknown;
}

export interface LogPayload {
  message: string;
  context?: LogContext;
  data?: Record<string, unknown>;
  level?: LogLevel;
}

const REDACT_KEYS = new Set([
  "oauth_token",
  "accessToken",
  "refreshToken",
  "stripeSecretKey",
  "cardNumber",
  "cvv",
  "nonce",
  "tokenId",
]);

function redactValue(key: string, value: unknown): unknown {
  if (value == null) {
    return value;
  }

  if (REDACT_KEYS.has(key)) {
    return "[REDACTED]";
  }

  if (typeof value === "string" && value.length > 200) {
    return `${value.substring(0, 197)}...`;
  }

  return value;
}

function redactObject<T extends Record<string, unknown> | undefined>(input: T): T {
  if (!input) {
    return input;
  }

  const result: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(input)) {
    if (typeof value === "object" && value !== null && !Array.isArray(value)) {
      result[key] = redactObject(value as Record<string, unknown>);
    } else if (Array.isArray(value)) {
      result[key] = value.map((item) =>
        typeof item === "object" && item !== null
          ? redactObject(item as Record<string, unknown>)
          : item
      );
    } else {
      result[key] = redactValue(key, value);
    }
  }

  return result as T;
}

function composeLogPayload({message, context, data, level = "info"}: LogPayload) {
  const redactedContext = redactObject(context);
  const redactedData = redactObject(data);

  return {message, context: redactedContext, data: redactedData, level};
}

export const logger = {
  debug(payload: LogPayload | string) {
    outputLog("debug", payload);
  },
  info(payload: LogPayload | string) {
    outputLog("info", payload);
  },
  warn(payload: LogPayload | string) {
    outputLog("warn", payload);
  },
  error(payload: LogPayload | string, error?: unknown) {
    outputLog("error", payload, error);
  },
};

function outputLog(level: LogLevel, payload: LogPayload | string, error?: unknown) {
  if (typeof payload === "string") {
    functions.logger[level](payload, error);
    return;
  }

  const composed = composeLogPayload({...payload, level});

  if (error) {
    functions.logger[level](composed, error);
  } else {
    functions.logger[level](composed);
  }
}

export function withHandler(handler: string, baseContext: LogContext = {}) {
  return {
    debug: (message: string, data?: Record<string, unknown>) =>
      logger.debug({message, context: {...baseContext, handler}, data}),
    info: (message: string, data?: Record<string, unknown>) =>
      logger.info({message, context: {...baseContext, handler}, data}),
    warn: (message: string, data?: Record<string, unknown>) =>
      logger.warn({message, context: {...baseContext, handler}, data}),
    error: (message: string, error?: unknown, data?: Record<string, unknown>) =>
      logger.error({message, context: {...baseContext, handler}, data}, error),
  };
}
