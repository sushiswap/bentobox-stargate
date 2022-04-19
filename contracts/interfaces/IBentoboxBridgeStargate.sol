// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.11;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./IBentoBoxMinimal.sol";
import "./IStargateRouter.sol";
import "./IStargateReceiver.sol";
import "../utils/BoringBatchable.sol";

interface IBentoboxBridgeStargate {
    function setBentoBoxApproval(
        address user,
        bool approved,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function approveToStargateRouter(IERC20 token) external;

    function teleport(BridgeParams memory bridgeParams) external payable;

    struct BridgeParams {
        uint16 dstChainId;
        address token;
        uint256 srcPoolId;
        uint256 dstPoolId;
        uint256 amount;
        uint256 amountMin;
        uint256 dustAmount;
        address receiver;
        address to;
        bool fromBento;
        bool toBento;
    }

    event Teleported(
        address indexed sender,
        address indexed token,
        uint256 indexed amount
    );

    event Received(
        address indexed to,
        address indexed token,
        uint256 indexed amount
    );
}
