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

// contracts deployed with 0.8.22v
- STABLE TOKEN: 0xF2CFDd6dfD0332E55EDc3e0D6D93331940087Cfd
- FARM SETTINGS: 0xe62C999737E070cEA40352a1c327baC0EF9195be
- FARM: 0x5d14D674b51bf6F755902c378818b474df120595
- PLOT: 0x40711209614420Ab5Db08625832D2E0194E472F4
- POTATO SEED: 0x9Fa4FA7360d7C370EBf4A8EFfA98fc2dAC1F585e
- POTATO PRODUCT: 0x07701406AB728Ca70b260cE8b7507C613602C079
- POTATO DISH: 0x11D5Db90973beA9fA3Af1D96eF900B4681b44E7A
- CORN SEED: 0x9Ff634963d636Da541398C9452573794FB6623ee
- CORN PRODUCT: 0x1b93113DAfadd27bf2906EeBC6B3eb8a5dc3Ddf7
- CORN DISH: 0xE076155eBA650310c20761F212A16B8146C9e1A7
- CARROT SEED: 0xB2c37799cfC3d92679580DeA1904996FB92d9008
- CARROT PRODUCT: 0xCa4642e7682f8BA6DD2cd7f4A76B60588F92d3f4
- CARROT DISH: 0xDd487A4075e99bDf737057aF2C63C1ABd9E249F5
- WEED PRODUCT: 0x83585F05038035E87C6AfA4D6400a87745eAB8BF
- WEED DISH: 0x1566B3A7064cF933311C08379BBD869B68e4736B

## Water

  - For simpler math plants are always absorbing water as long as they are planted (to avoid the need to recalculated the entire map each time)
  - Plots water level is not in sync in contract, one will only be updated once some action was taken that involves it (plant/harvest)
  

## NOTES:

- Currently the game deployed only on Polygon Amoy testnet.  
- Weed is a special plant whose product can only be obtained by overgrowing any other plant.
- Crafting dishes requires correct product array order (bug -> feature, allows for more recipes)