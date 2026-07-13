# In-App Purchase promotional images (1024×1024)

Apple requires **unique** promotional images per promoted IAP product (Guideline 2.3.2).

| File | Product ID | Upload to |
|------|------------|-----------|
| `route_premium_lifetime-1024.png` | `route_premium_lifetime` | App Store Connect → IAP → Lifetime → Promotional Image |
| `route_premium_monthly-1024.png` | `route_premium_monthly` | App Store Connect → IAP → Monthly → Promotional Image |

Do **not** upload the same image for both products.

If you are not promoting an IAP on the App Store, delete its promotional image in App Store Connect instead.

Regenerate from the lifetime base (adds labelled banners):

```bash
python3 scripts/generate-iap-promo-images.py
```
