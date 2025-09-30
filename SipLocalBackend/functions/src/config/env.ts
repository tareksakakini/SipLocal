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

let runtimeConfig: any = {};
try {
  runtimeConfig = functions.config();
} catch (error) {
  // functions.config() throws when no config is set (local CLI without firebase.json)
  runtimeConfig = {};
}

const stripeSecretKey =
  runtimeConfig?.stripe?.secret_key ?? process.env.STRIPE_SECRET_KEY;

const squareWebhookSignatureKey =
  runtimeConfig?.square?.webhook_signature_key ??
  process.env.SQUARE_WEBHOOK_SIGNATURE_KEY;

const rawSquareEnv =
  runtimeConfig?.square?.square_environment ??
  runtimeConfig?.square?.environment ??
  process.env.SQUARE_ENVIRONMENT;

const squareEnvRaw = (rawSquareEnv ?? "sandbox").toLowerCase();

const squareEnvironment: SquareEnvironmentName =
  squareEnvRaw === "production" ? "production" : "sandbox";

const oneSignalAppId =
  runtimeConfig?.onesignal?.app_id ?? process.env.ONESIGNAL_APP_ID;

const oneSignalApiKey =
  runtimeConfig?.onesignal?.rest_api_key ??
  runtimeConfig?.onesignal?.api_key ??
  process.env.ONESIGNAL_API_KEY;

export const appConfig: AppConfig = {
  nodeEnv,
  isProduction,
  isEmulator,
  square: {
    environment: squareEnvironment,
    webhookSignatureKey: squareWebhookSignatureKey,
  },
  stripe: {
    secretKey: stripeSecretKey,
  },
  onesignal: {
    appId: oneSignalAppId,
    apiKey: oneSignalApiKey,
  },
};

export const configValidation: ConfigValidation = {
  missingCritical: [],
  warnings: [],
};

if (!stripeSecretKey) {
  configValidation.missingCritical.push("STRIPE_SECRET_KEY");
}

if (!squareWebhookSignatureKey) {
  configValidation.missingCritical.push("SQUARE_WEBHOOK_SIGNATURE_KEY");
}

if (!oneSignalAppId || !oneSignalApiKey) {
  configValidation.warnings.push(
    "OneSignal credentials missing; order-ready push notifications will be disabled."
  );
}

if (!rawSquareEnv) {
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
