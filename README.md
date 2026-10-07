# Padeleiros — Raquetes de Padel

Loja simples de raquetes de padel, novas e usadas, em português de Portugal. O pagamento é por MB WAY.

Site: https://tomasgoulart.github.io/padelAzoresShop/

## O que faz

- **Página inicial:** grelha de raquetes com nome, estado, preço, vendedor e link para uma review no YouTube.
- **Página da raquete:** mais fotos, características e o botão **Adicionar ao cesto**.
- **Cesto:** o comprador indica o nome e o número MB WAY. Não precisa de conta para comprar.
- **Pagamento:** cada vendedor recebe diretamente por MB WAY. O comprador vê o valor, o número e uma referência, e envia a encomenda ao vendedor por WhatsApp.
- **Vender raquete:** quem entra com a conta Google pode anunciar raquetes com até 4 fotos. Os anúncios aparecem logo.
- **A minha conta:** lista os anúncios da pessoa e permite removê-los.

O site é um único ficheiro, `index.html`. Os anúncios, as fotos e as contas ficam no Supabase.

## Definições

No início do `<script>` em `index.html`:

- `SHOP.mbwayNumber` e `SHOP.whatsapp`: os números da loja, para as raquetes da própria loja.
- `SHOP.shipping`: opções de entrega das raquetes da loja.
- `SUPABASE`: endereço e chave pública do projeto Supabase. A chave pública pode estar no site.
- `RACKETS`: as raquetes da própria loja (os valores de `condition` e `shape` ficam em inglês).

## Base de dados (Supabase)

Corra estes ficheiros, por esta ordem, no **SQL Editor** do Supabase:

1. `supabase-setup.sql`: cria a tabela de anúncios e o espaço para as fotos.
2. `supabase-login.sql`: liga os anúncios às contas e só deixa quem entrou anunciar e remover os seus anúncios.

Para apagar um anúncio de spam: **Table Editor → listings**, apague a linha.

## Login com Google

1. Na Google Cloud Console, crie um **ID de cliente OAuth** do tipo **Aplicação Web**, com este URI de redirecionamento autorizado:
   `https://llyqlkdndiupwvczjenj.supabase.co/auth/v1/callback`
2. No Supabase, em **Authentication → Sign In / Providers → Google**, ative o Google e cole o ID de cliente e o segredo.
3. No Supabase, em **Authentication → URL Configuration**, defina o **Site URL** como `https://tomasgoulart.github.io/padelAzoresShop/` e adicione o mesmo endereço em **Redirect URLs**.

## Publicar com GitHub Pages

Em **Settings → Pages**, escolha **Deploy from a branch**, depois `main` e `/ (root)`.
