import * as dotenv from "dotenv";
import * as functions from "firebase-functions";

export type SquareEnvironmentName = "production" | "sandbox";

export interface AppConfig {
  nodeEnv: string;
  isProduction: boolean;
  isEmulator: boolean;
  square: {
    environment: SquareEnvironmentName;
    webhookSignatureKey?: string;
  };
  stripe: {
    secretKey?: string;
  };
  onesignal: {
    appId?: string;
    apiKey?: string;
  };
}

export interface ConfigValidation {
  missingCritical: string[];
  warnings: string[];
}

const isFirebaseRuntime = Boolean(process.env.K_SERVICE || process.env.FUNCTION_TARGET);

// Keep local .env support for emulator and CLI tooling
if (!isFirebaseRuntime) {
  dotenv.config();
}

const nodeEnv = process.env.NODE_ENV ?? "development";
const isProduction = nodeEnv === "production";
const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";

const squareEnvRaw = (process.env.SQUARE_ENVIRONMENT ?? "sandbox").toLowerCase();
const squareEnvironment: SquareEnvironmentName =
  squareEnvRaw === "production" ? "production" : "sandbox";

export const appConfig: AppConfig = {
  nodeEnv,
  isProduction,
  isEmulator,
  square: {
    environment: squareEnvironment,
    webhookSignatureKey: process.env.SQUARE_WEBHOOK_SIGNATURE_KEY,
  },
  stripe: {
    secretKey: process.env.STRIPE_SECRET_KEY,
  },
  onesignal: {
    appId: process.env.ONESIGNAL_APP_ID,
    apiKey: process.env.ONESIGNAL_API_KEY,
  },
};

export const configValidation: ConfigValidation = {
  missingCritical: [],
  warnings: [],
};

const criticalKeys: string[] = [
  "STRIPE_SECRET_KEY",
  "SQUARE_WEBHOOK_SIGNATURE_KEY",
];

for (const key of criticalKeys) {
  if (!process.env[key]) {
    configValidation.missingCritical.push(key);
  }
}

if (!process.env.ONESIGNAL_APP_ID || !process.env.ONESIGNAL_API_KEY) {
  configValidation.warnings.push(
    "OneSignal credentials missing; order-ready push notifications will be disabled."
  );
}

if (!process.env.SQUARE_ENVIRONMENT) {
  configValidation.warnings.push(
    "SQUARE_ENVIRONMENT not set; defaulting to sandbox."
  );
}

if (configValidation.missingCritical.length > 0) {
  const detail = configValidation.missingCritical.join(", ");
  const message = `[config] Missing critical environment variables: ${detail}`;

  if (appConfig.isProduction && !appConfig.isEmulator) {
    functions.logger.error(message);
  } else {
    functions.logger.warn(message);
  }
}

for (const warning of configValidation.warnings) {
  functions.logger.warn(`[config] ${warning}`);
}

export function requireConfigValue<T extends string | undefined>(
  value: T,
  key: string
): string {
  if (!value) {
    throw new Error(`[config] Missing required configuration value: ${key}`);
  }
  return value;
}

export function isSquareProductionEnvironment(): boolean {
  return appConfig.square.environment === "production";
}
