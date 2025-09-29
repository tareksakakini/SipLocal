SIPLOCAL BACKEND REFACTOR PLAN
==============================

Status legend
-------------
[x] Done
[~] In progress
[ ] Pending

Context snapshot
----------------
- `functions/src/index.ts` is a 3,563 line monolith combining Square, Stripe, Apple Pay, Clover, and Firestore logic alongside HTTP/callable handlers.
- Shared concerns (config, logging, error handling, data mappers) are duplicated inline, increasing risk of regressions.
- Secrets such as OAuth tokens appear in `src/migrate.ts`, indicating we need a safer configuration strategy before code churn.
- TypeScript setup relies on `tsc` only; there are no unit/integration tests validating payment/order flows.

Phase 0 – Assessment & Planning
-------------------------------
[x] 0.1 Inspect repo layout, dependencies, and deployed function surface area.
[x] 0.2 Produce detailed inventory of exported functions, request/response contracts, and external integrations to guard during refactors.

Phase 0.2 Inventory – Exported Cloud Functions
----------------------------------------------
- getMerchantTokens (`functions/src/index.ts:204`) – HTTP onRequest
  * Request: query/body `merchantId`; expects GET/POST with CORS pre-flight support.
  * Response: `200 { tokens }` or `4xx/5xx` error payloads.
  * Integrations: Firestore `merchant_tokens` collection.
- getCloverCredentials (`functions/src/index.ts:252`) – HTTP onRequest
  * Request: query/body `merchantId`; mirrors token endpoint CORS handling.
  * Response: `200 { credentials }` or error JSON.
  * Integrations: Firestore `clover_credentials` collection.
- processPayment (`functions/src/index.ts:299`) – Callable
  * Request: Square card nonce payload (`nonce`, `amount`, `merchantId`, `oauth_token`, optional `items` + customer metadata).
  * Response: Success envelope `{ success, transactionId, orderId, status, amount, currency, receiptNumber, receiptUrl }` or `HttpsError`.
  * Integrations: Square (locations, customers, orders, payments), Firestore (`merchant_tokens`, `orders`, `completion_tasks`), helper `completeAuthorizedOrder`, env `SQUARE_ENVIRONMENT`.
- processStripePayment (`functions/src/index.ts:690`) – Callable
  * Request: Stripe manual-capture intent payload (`amount`, `merchantId`, `oauth_token`, optional order/customer context).
  * Response: `{ success, transactionId, orderId: null, status: 'AUTHORIZED', amount, currency, stripePaymentIntentId, stripeClientSecret, receiptUrl }`.
  * Integrations: Stripe PaymentIntents, Square (location lookup), Firestore (`merchant_tokens`, `orders`), env `STRIPE_SECRET_KEY`, `SQUARE_ENVIRONMENT`.
- cancelApplePayPayment (`functions/src/index.ts:1095`) – Callable
  * Request: `{ transactionId }` (nested or direct).
  * Response: `{ success, message, refundId }` on Stripe refund of uncaptured charge.
  * Integrations: Firestore `orders`, Stripe Refunds API, env `STRIPE_SECRET_KEY`.
- captureApplePayPaymentManual (`functions/src/index.ts:1199`) – Callable
  * Request: `{ transactionId }`.
  * Response: `{ success, message }` after delegating to `captureApplePayPayment` helper.
  * Integrations: Same as helper (Firestore `orders`, Stripe capture, Square external order, env `STRIPE_SECRET_KEY`, `SQUARE_ENVIRONMENT`).
- processApplePayPayment (`functions/src/index.ts:1231`) – Callable
  * Request: Apple Pay payload (`amount`, `merchantId`, `oauth_token`, `tokenId`, optional order/customer context, optional `posType`).
  * Response: `{ success, transactionId, orderId|null, status: 'AUTHORIZED', amount, currency, stripeChargeId, receiptUrl }`.
  * Integrations: Stripe Charges (auth-only), Square (location, orders, payments), Firestore `orders`, helper `captureApplePayPayment`, env `STRIPE_SECRET_KEY`, `SQUARE_ENVIRONMENT`; routes `posType === 'clover'` to `processApplePayPaymentClover` (Stripe + Clover REST via axios).
- completeStripePayment (`functions/src/index.ts:1733`) – Callable
  * Request: `{ clientSecret, transactionId }`.
  * Response: `{ success, transactionId, orderId, paymentStatus, message }` once PaymentIntent is captured and Square order recorded.
  * Integrations: Stripe PaymentIntents, Square (orders, payments), Firestore (`orders`, `merchant_tokens`), env `STRIPE_SECRET_KEY`, `SQUARE_ENVIRONMENT`.
- submitOrderWithExternalPayment (`functions/src/index.ts:2006`) – Callable
  * Request: External order payload (`amount`, `merchantId`, `oauth_token`, optional items/customer data).
  * Response: `{ success, transactionId, orderId, status: 'SUBMITTED', amount, currency, receiptNumber, receiptUrl }`.
  * Integrations: Square (locations, customers, orders), Firestore (`merchant_tokens`, `orders`), env `SQUARE_ENVIRONMENT`.
- cancelOrder (`functions/src/index.ts:2482`) – Callable
  * Request: `{ paymentId }`.
  * Response: `{ success, message }` after cancelling linked Square/Stripe payment and updating Firestore.
  * Integrations: Firestore (`orders`, `merchant_tokens`), Stripe PaymentIntents, Square (payments, orders), env `STRIPE_SECRET_KEY`, `SQUARE_ENVIRONMENT`.
- completeAuthorizedOrderHttp (`functions/src/index.ts:2668`) – HTTP onRequest
  * Request: POST body `{ paymentId }` with CORS pre-flight.
  * Response: `{ success, message }` or error JSON, delegates to `completeAuthorizedOrder`.
  * Integrations: Same as helper (Firestore `orders`, Square payments), env `SQUARE_ENVIRONMENT`.
- squareWebhook (`functions/src/index.ts:2705`) – HTTP onRequest
  * Request: Square webhook payload + `x-square-hmacsha256-signature` header (verification currently disabled).
  * Response: `200 'Webhook processed'` when handled; various `4xx/5xx` on validation failures.
  * Integrations: Firestore (`orders`, `users`), helper handlers (`handleOrderUpdated`, `handleOrderCreated`, `handleOrderFulfillmentUpdated`), OneSignal via `sendOrderReadyNotification`, env `SQUARE_WEBHOOK_SIGNATURE_KEY`, `ONESIGNAL_APP_ID`, `ONESIGNAL_API_KEY`.
- submitCloverOrderWithExternalPayment (`functions/src/index.ts:3121`) – Callable
  * Request: Clover external order payload (`amount`, `merchantId`, `oauth_token`, optional items/customer data).
  * Response: `{ success, transactionId, orderId, message, status: 'SUBMITTED' }`.
  * Integrations: Clover REST API via axios, Firestore `orders`.
- migrateTokens (`functions/src/migrate.ts:4`, re-exported in `functions/src/index.ts`) – HTTP onRequest
  * Request: Any method; rejects when `NODE_ENV === 'production'`.
  * Response: Migration report `{ success, message, migrated }` or error JSON.
  * Integrations: Firestore `merchant_tokens`; currently seeds hard-coded Square secrets.
[x] 0.3 Flag quick wins and high-risk issues (secrets in code, missing retries, duplicated Square order creation) to prioritize mitigation.

Phase 0.3 Risk & Quick-Win Notes
--------------------------------
- **Webhooks** – `squareWebhook` currently skips signature verification, leaving the endpoint open to spoofed status updates; reinstate verification before structural refactors.
- **Secrets exposure** – `getMerchantTokens`/`getCloverCredentials` return OAuth credentials over CORS-enabled HTTP without auth checks, and `orders` documents persist `oauthToken`; tightening access control plus redacting response payloads is urgent.
- **Hard-coded credentials** – `src/migrate.ts` seeds live OAuth tokens; move to environment-based seeding or admin-only tooling to avoid accidental leaks.
- **Async orchestration** – Payment capture relies on `setTimeout` inside Cloud Functions (`processPayment`, `processApplePayPayment`) which is unreliable in serverless; replace with Cloud Tasks / scheduled retries.
- **Duplicated payment logic** – Square order creation and Firestore writes are copy-pasted across handlers, multiplying bug risk; prioritize extraction into services once foundation is in place.
- **Logging hygiene** – Many handlers log full request payloads (including tokens/emails); sanitize logs and centralize logging helper early.

Phase 1 – Foundation & Project Structure
----------------------------------------
[x] 1.1 Introduce explicit configuration module (env validation, secret access) and remove ad-hoc `dotenv.config` usage.
[ ] 1.2 Sketch target folder layout (`config/`, `services/`, `data/`, `handlers/`, `utils/`) and add barrel exports to preserve Firebase entrypoints.
[ ] 1.3 Add lightweight logging/error helper capturing context + standardized error translation for client-safe messages.

Phase 1 Foundation Blueprint
----------------------------
- Directory layout draft:
  * `src/config` – env loader, runtime flags, shared constants.
  * `src/utils` – logging, error helpers, general utilities.
  * `src/data` – Firestore repositories (orders, merchant tokens, completion tasks).
  * `src/services` – integrations (`square`, `stripe`, `clover`, `notifications`).
  * `src/handlers` – callable/http entrypoints composed from services.
- Configuration approach:
  * `config/env.ts` loads environment variables once, validates required keys, exposes normalized config object.
  * Extend current `dotenv` usage but guard so firebase-managed deployments aren’t broken.
  * Provide helper to retrieve optional secrets with warnings instead of crashes in emulator/dev.
- Logging helper goal: wrap `functions.logger` to add consistent context (request id, handler) and redact sensitive fields.
- Initial refactor path: build `config` + `utils/logger` first, then migrate handlers incrementally while keeping exports in `index.ts`.

Phase 2 – Domain Modules & Shared Types
---------------------------------------
[ ] 2.1 Define shared TypeScript types/interfaces for orders, payments, and Firestore documents.
[ ] 2.2 Extract Firestore data access (orders, merchant tokens, completion tasks) into repository-style helpers with central timestamp handling.
[ ] 2.3 Extract Square integration (client factory, order creation, status mapping) into dedicated service.
[ ] 2.4 Extract Stripe/Apple Pay logic into cohesive service with capture/cancel flows and shared validation.
[ ] 2.5 Encapsulate Clover API calls and credential retrieval in a separate module with consistent error surfaces.

Phase 3 – Handler Refactors (Incremental)
-----------------------------------------
[ ] 3.1 Refactor token/credential HTTP endpoints to reuse config + data modules, ensuring CORS handling is centralized.
[ ] 3.2 Refactor `processPayment` (Square card nonce flow) to use new services and data layer.
[ ] 3.3 Refactor Stripe + Apple Pay callable handlers, delegating to shared services and reducing branching complexity.
[ ] 3.4 Refactor order management helpers (`submitOrderWithExternalPayment`, `cancelOrder`, `completeAuthorizedOrderHttp`, webhooks) to new module boundaries.
[ ] 3.5 Ensure Firebase export surface (`index.ts`) becomes thin composition layer calling modular handlers.

Phase 4 – Safety Nets & Quality Gates
-------------------------------------
[ ] 4.1 Add targeted unit/integration tests (mocks for Square/Stripe) covering happy-path + key failure modes for each service.
[ ] 4.2 Update ESLint/TypeScript config if needed to enforce stricter checks (no implicit any, consistent return types).
[ ] 4.3 Document manual regression checklist and emulator commands for user to validate between phases.

Phase 5 – Security & Operations
-------------------------------
[ ] 5.1 Remove hard-coded secrets from `migrate.ts`; replace with secure import strategy or scripts reading from env/Firestore dev data.
[ ] 5.2 Document required Firebase secrets and how to provision them per environment (dev/test/prod).
[ ] 5.3 Review logging for sensitive data leakage and ensure errors remain actionable without exposing PII.

Rolling Notes / Decisions
-------------------------
- 2025-09-29 Introduced `src/config/env.ts` with centralized env loading/validation; Firebase Functions now consume `appConfig` instead of direct `process.env` access.
