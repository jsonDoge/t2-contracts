# T2 farm (tokentoken)

**Contracts**:  
Seed -> ERC20 tokens with 0 decimals.  
Product -> ERC20 token with 0 decimals.  
Dish -> ERC721 token.  
Plot  -> ERC721 token with 0 decimals and a limited cap (currently expected at 1000000).  
Farm  -> Main interaction contract. Player wallets can perform these actions:
  - **buyPlot** -> deposit Farm accepted tokens and receive a Plot.
  - **buySeeds** -> deposit Farm accepted tokens and receive a Seed/Seeds.
  - **plant** -> deposits seeds + plot -> creates a plant.
  - **harvest** -> harvests existing plant - wallet receives back the plot and products (quantity determined by seed yield param).
  - **convertProductsToSeeds** -> deposit products receive same quantity of seeds.
  - **convertProductsToDish** -> deposit required quantity of products receive one Dish token.

[Temp] Stable Token -> Freely mint Farm accepted ERC20 tokens.  
Farm settings -> contains seed-product mapping and plot contract reference.  

## Future plans

  - Consider moving farm shop to uniswap (buy seeds in uniswap).
  - Adding an increasing cost to crafting Dishes so their value would naturally increase over time.

## Farm setting requirements

  - SEASON_DURATION - single season duration in blocks (total 4 seasons Winter, Spring, Summer and Autumn).
  - PLOT_WATER_REGEN_RATE - plot water gain per block.
  - PLANT_WATER_ABSORB_RATE - plant water absorb rate from plot it's planted on.
  - PLANT_NEIGHBOR_WATER_ABSORB_RATE - plant water absorb rate from direct neighbor plot.
  - PLOT_MAX_WATER - plot max possible amount of water accumulation.
  - PLOT_AREA_MAX_X - total game area X length in plots.
  - PLOT_AREA_MAX_Y - total game area Y length in plots.

## Contracts

Each item has its own contract (Products/Seeds/Dishes/Plot).
Contract used to manage them and contain the state of plants is the Farm.

At the moment of writing hardhat supports up to 0.8.22 (currently 0.8.22v used in code)

// contracts deployed with 0.7.6v
- Stable token:  0x451c4001eb9E7D3e30DD4Ec5Fda820f6fb2C3DD5
- Farm settings:  0xDB56aa600FAe785F5EBcB1175eEee9913D088aAa
- Farm:  0x1308253ca456bFad6B536B29A800886C2aE49E5B
- Plot:  0x3c76a3B25899adB0D74bEC0a7b1505220c2DF917
- Weed product:  0x91CdCF81008f0b0A827E20f0570D9b07a170CE90
- Potato seed:  0xF6F44ede48Fc55726D13F884C3b3F47eAe276eCc
- Potato product:  0x3bb9950ee421201e9bE9313C00a99Fb44Afa5cb2
- Potato dish:  0x7b6C85AE28F6cfcEa5f34Fb3b8367B0c344668BE
- Corn seed:  0x1d3773FFD3095fA37eB819D0510f82854871d9f8
- Corn product:  0x3Ce9f52EA05EA3F5f08d80a9c748C6010dd97560
- Corn dish:  0xc75474fe1E08386F881822872045dEAb818857de
- Carrot seed:  0x45c54384D15796b494eCA71aa205ad90c3b9d940
- Carrot product:  0xa5bA5adB5D949150ecaDB2E1f4bEE9A47CD62370
- Carrot dish:  0x413b118eD98AE2F58d69F1aAf55Fd4a1f9922649

## NOTES:

- Currently the game deployed only on Polygon Mumbai testnet.  
- Weed is a special plant whose product can only be obtained by overgrowing any other plant.
- Crafting dishes requires correct product array order (bug -> feature, allows for more recipes)