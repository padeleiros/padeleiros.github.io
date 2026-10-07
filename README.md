# Bandeja — Padel Rackets

A simple one-page shop for selling padel rackets, new and used. Payment is by MB WAY.

## What it does

- **Front page:** a grid of rackets showing name, condition, price and a YouTube review link.
- **Racket page:** more photos, specs, and an **Add to basket** button.
- **Basket and checkout:** the buyer picks delivery and enters their name and MB WAY phone number.
- **Payment:** the buyer sees the total, your MB WAY number and an order reference, then sends you the order on WhatsApp with one tap.

There is no server or database. The whole site is one file, `index.html`.

## Editing the shop

Open `index.html` and find the `SHOP SETTINGS` section near the top of the `<script>`.

- `SHOP.mbwayNumber` is your MB WAY number, shown to buyers.
- `SHOP.whatsapp` is the same number with country code, digits only, for example `351912345678`.
- `SHOP.shipping` holds the delivery options and their prices.
- `RACKETS` is your list of rackets. Each racket has these fields:
  - `id`: a short unique name, using letters and digits only
  - `name`, `price`, `weight`, `core`, `face`, `year`, `notes`
  - `condition`: one of `New`, `Like new`, `Very good`, `Good` or `Fair`
  - `shape`: one of `round`, `teardrop` or `diamond`
  - `review`: a YouTube link
  - `colors`: three colours used to draw the placeholder pictures

## Publishing with GitHub Pages

1. Push this folder to a GitHub repository.
2. In the repository, go to **Settings → Pages**.
3. Choose **Deploy from a branch**, then select `main` and `/ (root)`.
4. Your site will appear at `https://<your-username>.github.io/<repo-name>/`.
