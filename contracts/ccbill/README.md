# Dormant CCBill staging contract

This directory declares secret **names only**. It is intentionally not included
by the active LAN manifest or Argo application. It must not be activated until:

- the CCBill source release is deployed to staging;
- CCBill approves the account, FlexForm, passthrough parameters, prices,
  currencies and recurring terms;
- `secret/libreplay/staging/ccbill` contains every declared property;
- `CCBILL_PSP_APPROVAL_REF`, `CCBILL_SANDBOX_EVIDENCE_REF` and
  `CCBILL_PASSTHROUGH_APPROVAL_REF` point to reviewed evidence;
- ExternalSecret reports Ready and sandbox sale/decline tests pass.

Non-secret application configuration required at activation:

```yaml
PAYMENT_PROVIDER: ccbill
ENABLE_MOCK_PAYMENTS: "false"
CCBILL_API_BASE_URL: https://api.ccbill.com
CCBILL_DATALINK_BASE_URL: https://datalink.ccbill.com
CCBILL_MIN_PRICE_CENTS: "<contract value>"
CCBILL_MAX_PRICE_CENTS: "<contract value>"
CCBILL_ALLOWED_CURRENCIES: "<contract mapping>"
CCBILL_SINGLE_BILLING_PERIOD_DAYS: "<contract value>"
CCBILL_RECURRING_PERIOD_DAYS: "<contract value>"
CCBILL_NUM_REBILLS: "<contract value>"
CCBILL_SUCCESS_URL: https://<staging-host>/<locale>/payments/success
CCBILL_CANCEL_URL: https://<staging-host>/<locale>/payments/cancel
CCBILL_WEBHOOK_URL: https://<staging-host>/api/webhooks/ccbill
CCBILL_WEBHOOK_ALLOWED_CIDRS: 64.38.212.0/24,64.38.215.0/24,64.38.240.0/24,64.38.241.0/24
```

Do not replace placeholders above in Git based on guesses. Any staging or
production ConfigMap must remain `PAYMENT_PROVIDER=disabled` until PMO closes
the external evidence gate. The separate LAN demo may continue using its
explicit mock provider.
