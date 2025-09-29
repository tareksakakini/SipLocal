import {SquareClient, SquareEnvironment} from "square";
import {appConfig} from "../../config";

export interface SquareClientOptions {
  token: string;
  environmentOverride?: "sandbox" | "production";
}

export function createSquareClient({token, environmentOverride}: SquareClientOptions) {
  const environmentName = environmentOverride ?? appConfig.square.environment;
  const environment = environmentName === "production"
    ? SquareEnvironment.Production
    : SquareEnvironment.Sandbox;

  return new SquareClient({
    token,
    environment,
  });
}
