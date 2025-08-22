// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import './interfaces/IFusionXV3PoolDeployer.sol';

import './FusionXV3Pool.sol';

contract FusionXV3PoolDeployer is IFusionXV3PoolDeployer {
    struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
    }


    bytes32 public constant INIT_CODE_PAIR_HASH =
        keccak256(abi.encodePacked(type(FusionXV3Pool).creationCode));

    /****/
    Parameters public override parameters;

    address public factoryAddress;
    address public owner;

    /// @notice Emitted when factory address is set
    event SetFactoryAddress(address indexed factory);
    
    /// @notice Emitted when owner is changed
    event OwnerChanged(address indexed previousOwner, address indexed newOwner);

    modifier onlyFactory() {
        require(msg.sender == factoryAddress, "only factory can call deploy");
        _;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);
    }

    function setFactoryAddress(address _factoryAddress) external onlyOwner {
        require(factoryAddress == address(0), "already initialized");

        factoryAddress = _factoryAddress;

        emit SetFactoryAddress(_factoryAddress);
    }
    
    /// @notice Set new owner
    /// @param _owner The new owner address
    function setOwner(address _owner) external onlyOwner {
        require(_owner != address(0), "zero address");
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    /// @dev Deploys a pool with the given parameters by transiently setting the parameters storage slot and then
    /// clearing it after deploying the pool.
    /// @param factory The contract address of the FusionX V3 factory
    /// @param token0 The first token of the pool by address sort order
    /// @param token1 The second token of the pool by address sort order
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @param tickSpacing The spacing between usable ticks
    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) external override onlyFactory returns (address pool) {
        parameters = Parameters({factory: factory, token0: token0, token1: token1, fee: fee, tickSpacing: tickSpacing});
        pool = address(new FusionXV3Pool{salt: keccak256(abi.encode(token0, token1, fee))}());
        delete parameters;
    }
}