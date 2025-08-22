
import { ContractFactory } from 'ethers'
import { ethers, network } from 'hardhat'
import fs from 'fs'
import { configs } from '@summitx/common/config';
import { tryVerify } from '@summitx/common/verify'



type ContractJson = { abi: any; bytecode: string }
const artifacts: { [name: string]: ContractJson } = {
  // eslint-disable-next-line global-require
  PoolCreationHandler: require('../artifacts/contracts/PoolCreationHandler.sol/PoolCreationHandler.json'),
}

// Factory ABIs for setting the handler
const V2_FACTORY_ABI = [
  'function setPoolCreationHandler(address _handler) external',
  'function poolCreationHandler() view returns (address)',
  'function feeToSetter() view returns (address)'
]

const V3_FACTORY_ABI = [
  'function setPoolCreationHandler(address _handler) external',
  'function poolCreationHandler() view returns (address)',
  'function owner() view returns (address)'
]

async function main() {
  const [deployer] = await ethers.getSigners()
  

  console.log('=' .repeat(50))
  console.log('Deploying and Setting up PoolCreationHandler')

  const networkName = network.name
  console.log('Network:', networkName)
  console.log('Deployer:', deployer.address)
  console.log('=' .repeat(50))

  const config = configs[networkName as keyof typeof configs]
  
  // Read factory addresses from deployment files
  let v2FactoryAddress = ''
  let v3FactoryAddress = ''
  const v3DeployedContracts = await import(`@summitx/v3-core/deployments/${networkName}.json`)
  const v2DeployedContracts = await import(`@summitx/v2-core/deployments/${networkName}.json`)  
  v2FactoryAddress = v2DeployedContracts.SummitXV2Factory
  v3FactoryAddress = v3DeployedContracts.SummitXV3Factory
  
  if (!v2FactoryAddress && !v3FactoryAddress) {
    throw new Error('No factories found! Deploy V2 and/or V3 factories first.')
  }
  else {
    console.log('V2 Factory:', v2FactoryAddress)
    console.log('V3 Factory:', v3FactoryAddress)
  }
  
  // Get pool helper addresses from environment or use zero addresses
  const poolHelper = config.poolHelperV3 || ethers.constants.AddressZero
  const poolHelperUniV2 = config.poolHelperV2 || ethers.constants.AddressZero
  
  console.log('\nPool Helpers:')
  console.log('V3 Pool Helper:', poolHelper)
  console.log('V2 Pool Helper:', poolHelperUniV2)
  
  // Deploy PoolCreationHandler
  console.log('\n' + '=' .repeat(50))
  console.log('Deploying PoolCreationHandler...')
  
  const PoolCreationHandler = new ContractFactory(
    artifacts.PoolCreationHandler.abi,
    artifacts.PoolCreationHandler.bytecode,
    deployer
  )
  
  const poolCreationHandler = await PoolCreationHandler.deploy(poolHelper, poolHelperUniV2)
  await poolCreationHandler.deployed()
  
  console.log('✅ PoolCreationHandler deployed to:', poolCreationHandler.address)
  
  // Set handler on V2 Factory
  if (v2FactoryAddress) {
    console.log('\n' + '=' .repeat(50))
    console.log('Setting handler on V2 Factory...')
    
    const v2Factory = new ethers.Contract(v2FactoryAddress, V2_FACTORY_ABI, deployer)
    
    // Check current handler
    const currentV2Handler = await v2Factory.poolCreationHandler()
    if (currentV2Handler !== ethers.constants.AddressZero) {
      console.log('⚠️  V2 Factory already has a handler:', currentV2Handler)
      console.log('   Updating to new handler...')
    }
    
    // Set the handler
    const tx1 = await v2Factory.setPoolCreationHandler(poolCreationHandler.address)
    await tx1.wait()
    console.log('✅ Handler set on V2 Factory')
  }
  
  // Set handler on V3 Factory
  if (v3FactoryAddress) {
    console.log('\n' + '=' .repeat(50))
    console.log('Setting handler on V3 Factory...')
    
    const v3Factory = new ethers.Contract(v3FactoryAddress, V3_FACTORY_ABI, deployer)
    
    // Check current handler
    const currentV3Handler = await v3Factory.poolCreationHandler()
    if (currentV3Handler !== ethers.constants.AddressZero) {
      console.log('⚠️  V3 Factory already has a handler:', currentV3Handler)
      console.log('   Updating to new handler...')
    }
    
    // Set the handler
    const tx2 = await v3Factory.setPoolCreationHandler(poolCreationHandler.address)
    await tx2.wait()
    console.log('✅ Handler set on V3 Factory')
  }
  
  // Save deployment info
  const deployment = {
    PoolCreationHandler: poolCreationHandler.address,
    poolHelper: poolHelper,
    poolHelperUniV2: poolHelperUniV2,
    v2Factory: v2FactoryAddress || 'Not set',
    v3Factory: v3FactoryAddress || 'Not set',
    deployedAt: new Date().toISOString(),
    network: networkName,
    deployer: deployer.address,
  }
  

  
  fs.writeFileSync(
    `./deployments/${networkName}.json`,
    JSON.stringify(deployment, null, 2)
  )
  
  // Update main deployment file
  try {
    const mainDeploymentPath = `../../../deployments/${networkName}.json`
    let mainDeployment = {}
    
    if (fs.existsSync(mainDeploymentPath)) {
      mainDeployment = JSON.parse(fs.readFileSync(mainDeploymentPath, 'utf8'))
    }
    
    mainDeployment.PoolCreationHandler = poolCreationHandler.address
    
    fs.writeFileSync(mainDeploymentPath, JSON.stringify(mainDeployment, null, 2))
    console.log('\n✅ Updated main deployment file')
  } catch (e) {
    console.log('\n⚠️  Could not update main deployment file:', e.message)
  }
  
  // Summary
  console.log('\n' + '=' .repeat(50))
  console.log('DEPLOYMENT COMPLETE!')
  console.log('=' .repeat(50))
  console.log('\nSummary:')
  console.log('- PoolCreationHandler:', poolCreationHandler.address)
  if (v2FactoryAddress) console.log('- V2 Factory configured ✅')
  if (v3FactoryAddress) console.log('- V3 Factory configured ✅')
  
  console.log('\n📝 Configuration Tips:')
  console.log('1. To update pool helpers, set environment variables:')
  console.log('   export POOL_HELPER_V3=0x...')
  console.log('   export POOL_HELPER_V2=0x...')
  console.log('\n2. To manage blacklists/whitelists:')
  console.log('   - Use setTokenBlacklist(token, true/false)')
  console.log('   - Use setCreatorBlacklist(address, true/false)')
  console.log('   - Use setPairBlacklist(token0, token1, true/false)')
  console.log('\n3. To pause all pool creation:')
  console.log('   - Use setPaused(true)')
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })