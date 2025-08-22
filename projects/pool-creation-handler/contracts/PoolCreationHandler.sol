// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import './interfaces/IPoolCreationHandler.sol';
import './interfaces/IGaugeToken.sol';
import './interfaces/IPoolHelper.sol';
import './interfaces/ILaunchpadGauge.sol';
/**
 * @title PoolCreationHandler
 * @notice Unified pool creation handler for both SummitX V2 and V3 factories
 * @dev Provides validation logic to prevent pool creation for certain assets
 * and enforces special rules for tokens with gauges
 */
contract PoolCreationHandler is IPoolCreationHandler {
    address public owner;
    
    // Pool helpers that are authorized to create pools for gauge tokens
    IPoolHelper public immutable poolHelper;
    IPoolHelperUniV2 public immutable poolHelperUniV2;
    
    event OwnerChanged(address indexed previousOwner, address indexed newOwner);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "PoolCreationHandler: FORBIDDEN");
        _;
    }
    
    constructor(address _poolHelper, address _poolHelperUniV2) {
        owner = msg.sender;
        poolHelper = IPoolHelper(_poolHelper);
        poolHelperUniV2 = IPoolHelperUniV2(_poolHelperUniV2);
        emit OwnerChanged(address(0), msg.sender);
    }
    
    /**
     * @notice Check if a V2 pool creation should be allowed
     * @param token0 First token address
     * @param token1 Second token address
     * @param creator Address attempting to create the pool
     * @return canCreate Whether pool creation is allowed
     * @return reason Rejection reason if not allowed
     */
    function beforeV2PoolCreation(
        address token0,
        address token1,
        address creator
    ) external view override returns (bool canCreate, string memory reason) {
        
        // Check if either token has a gauge
        bool token0HasGauge = _hasGauge(token0);
        bool token1HasGauge = _hasGauge(token1);
        
        // If either token has a gauge, creator must be the poolHelperUniV2
        if (token0HasGauge || token1HasGauge) {
            if(token0HasGauge && _isTokenGraduated(token0)) {
                return (true, "");
            }
            if(token1HasGauge && _isTokenGraduated(token1)) {
                return (true, "");
            }
            if (creator != address(poolHelperUniV2)) {
                return (false, "PoolCreationHandler: Only poolHelperUniV2 can create pools for gauge tokens");
            }
        }
        return (true, "");
    }
    
    /**
     * @notice Check if a V3 pool creation should be allowed
     * @param token0 First token address
     * @param token1 Second token address
     * @param fee Fee tier for the pool
     * @param creator Address attempting to create the pool
     * @return canCreate Whether pool creation is allowed
     * @return reason Rejection reason if not allowed
     */
    function beforeV3PoolCreation(
        address token0,
        address token1,
        uint24 fee,
        address creator
    ) external view override returns (bool canCreate, string memory reason) {
        
        // Check if either token has a gauge
        bool token0HasGauge = _hasGauge(token0);
        bool token1HasGauge = _hasGauge(token1);
        
        // If either token has a gauge, creator must be the poolHelper
        if (token0HasGauge || token1HasGauge) {
            if(token0HasGauge && _isTokenGraduated(token0)) {
                return (true, "");
            }
            if(token1HasGauge && _isTokenGraduated(token1)) {
                return (true, "");
            }
            if (creator != address(poolHelper)) {
                return (false, "PoolCreationHandler: Only poolHelper can create pools for gauge tokens");
            }
        }
        return (true, "");
    }
    
    
    /**
     * @notice Check if a token has a gauge
     * @param token The token address to check
     * @return hasGauge Whether the token has a gauge
     */
    function _hasGauge(address token) private view returns (bool hasGauge) {
        // Use try-catch to safely check if the token has a gauge method
        try IGaugeToken(token).gauge() returns (address gauge) {
            // If gauge address is not zero, token has a gauge
            hasGauge = gauge != address(0);
        } catch {
            // If the call fails, token doesn't have a gauge
            hasGauge = false;
        }
    }

    function _isTokenGraduated(address token) private view returns (bool isGraduated) {
        // Use try-catch to safely check if the token has a gauge method
            try ILaunchpadGauge(IGaugeToken(token).gauge()).pool() returns (address pool) {
                // If pool address is not zero, token has a gauge
                isGraduated = pool != address(0);
            } catch {
                // If the call fails, token doesn't have a gauge
                    isGraduated = false;
                }
        
    }

    function isTokenGraduated(address token) external view returns (bool isGraduated) {
        return _isTokenGraduated(token);
    }
    
    /**
     * @notice Check if a token has a gauge (external view for testing)
     * @param token The token address to check
     * @return Whether the token has a gauge
     */
    function hasGauge(address token) external view returns (bool) {
        return _hasGauge(token);
    }
    
    
    function setOwner(address _owner) external onlyOwner {
        require(_owner != address(0), "PoolCreationHandler: Zero address");
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }
    
    
}