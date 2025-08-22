// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface IGaugeToken {
    /// @notice Address of the gauge responsible for managing the token
    function gauge() external view returns (address);
}