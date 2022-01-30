# To run the project 

## Run a hardhat node 

```
npx hardhat node
```

## Deploy contract to localhost 

```
npx hardhat run scripts/deploy.js --network localhost
```

> copy the respective values `nftmarketplaceaddress` and `nftaddress` to `config.js` file in the project root

## Run the server

```
npm run dev
```

# If you get this error ;

## Error: error:0308010C:digital envelope routines::unsupported

> solution : https://github.com/webpack/webpack/issues/14532#issuecomment-947012063
> set the env variable as `export NODE_OPTIONS=--openssl-legacy-provider`
