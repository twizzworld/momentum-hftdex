/*
███╗░░░███╗░█████╗░███╗░░░███╗███████╗███╗░░██╗████████╗██╗░░░██╗███╗░░░███╗
████╗░████║██╔══██╗████╗░████║██╔════╝████╗░██║╚══██╔══╝██║░░░██║████╗░████║
██╔████╔██║██║░░██║██╔████╔██║█████╗░░██╔██╗██║░░░██║░░░██║░░░██║██╔████╔██║
██║╚██╔╝██║██║░░██║██║╚██╔╝██║██╔══╝░░██║╚████║░░░██║░░░██║░░░██║██║╚██╔╝██║
██║░╚═╝░██║╚█████╔╝██║░╚═╝░██║███████╗██║░╚███║░░░██║░░░╚██████╔╝██║░╚═╝░██║
╚═╝░░░░░╚═╝░╚════╝░╚═╝░░░░░╚═╝╚══════╝╚═╝░░╚══╝░░░╚═╝░░░░╚═════╝░╚═╝░░░░░╚═╝

██╗░░██╗███████╗████████╗██████╗░███████╗██╗░░██╗
██║░░██║██╔════╝╚══██╔══╝██╔══██╗██╔════╝╚██╗██╔╝
███████║█████╗░░░░░██║░░░██║░░██║█████╗░░░╚███╔╝░
██╔══██║██╔══╝░░░░░██║░░░██║░░██║██╔══╝░░░██╔██╗░
██║░░██║██║░░░░░░░░██║░░░██████╔╝███████╗██╔╝╚██╗
╚═╝░░╚═╝╚═╝░░░░░░░░╚═╝░░░╚═════╝░╚══════╝╚═╝░░╚═╝
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
 * @title PriceOracle
 * @author twizzwrld
 *
 * The PriceOracle contract interacts with the Razor Network Oracle to fetch price feeds for various assets.
 *
 * This contract serves as a bridge between the Ethereum Virtual Machine (EVM)-compatible chains and the Razor Schain,
 * allowing decentralized applications (DApps) on Ethereum to access real-time price data provided by Razor Network.
 *
 * @notice This contract provides functions to fetch and calculate asset prices based on the Razor Network Oracle's data.
 */

interface ITransparentForwarder {
    function getResult(bytes32 _name) external payable returns (uint256, int8);
}

contract PriceOracle {
    ITransparentForwarder public transparentForwarder;
    uint256 public latestResult;
    int8 public latestPower;

    constructor(address _forwarderAddress) {
        transparentForwarder = ITransparentForwarder(_forwarderAddress);
    }

    function fetchPrice(bytes32 assetName) public payable returns (uint256, int8) {
        (uint256 result, int8 power) = transparentForwarder.getResult{ value: msg.value }(assetName);
        latestResult = result;
        latestPower = power;
        return (result, power);
    }

    function calculatePrice() public view returns (uint256) {
        return latestResult * 10 ** -latestPower;
    }
}
