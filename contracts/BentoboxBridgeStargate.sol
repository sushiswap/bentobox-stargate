// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.11;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./interfaces/IBentoBoxMinimal.sol";
import "./interfaces/IStargateRouter.sol";
import "./interfaces/IStargateReceiver.sol";

contract BentoboxBridgeStargate is IStargateReceiver {
    struct BridgeParams {
        uint16 dstChainId;
        address token;
        uint256 srcPoolId;
        uint256 dstPoolId;
        uint256 amount;
        uint256 amountMin;
        address receiver;
        address to;
        bool fromBento;
        bool toBento;
    }

    IBentoBoxMinimal public immutable bentoBox;
    IStargateRouter public immutable stargateRouter;

    constructor(IBentoBoxMinimal _bentoBox, IStargateRouter _stargateRouter) {
        stargateRouter = _stargateRouter;
        bentoBox = _bentoBox;
        _bentoBox.registerProtocol();
    }

    function setBentoBoxApproval(
        address user,
        bool approved,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        bentoBox.setMasterContractApproval(
            user,
            address(this),
            approved,
            v,
            r,
            s
        );
    }

    function approveToStargateRouter(IERC20 token) external {
        token.approve(address(stargateRouter), type(uint256).max);
    }

    function teleport(BridgeParams memory bridgeParams) external payable {
        if (bridgeParams.fromBento) {
            bentoBox.withdraw(
                bridgeParams.token,
                msg.sender,
                address(this),
                bridgeParams.amount,
                0
            );
        } else {
            IERC20(bridgeParams.token).transferFrom(
                msg.sender,
                address(this),
                bridgeParams.amount
            );
        }

        bytes memory payload = abi.encode(
            bridgeParams.toBento,
            bridgeParams.to
        );

        stargateRouter.swap{value: address(this).balance}(
            bridgeParams.dstChainId,
            bridgeParams.srcPoolId,
            bridgeParams.dstPoolId,
            payable(msg.sender),
            bridgeParams.amount,
            bridgeParams.amountMin,
            IStargateRouter.lzTxObj(
                500000,
                0,
                abi.encodePacked(bridgeParams.receiver)
            ),
            abi.encodePacked(bridgeParams.receiver),
            payload
        );
    }

    function sgReceive(
        uint16 _chainId,
        bytes memory _srcAddress,
        uint256 _nonce,
        address _token,
        uint256 amountLD,
        bytes memory payload
    ) external override {
        (bool toBento, address to) = abi.decode(payload, (bool, address));
        if (toBento) {
            IERC20(_token).transfer(address(bentoBox), amountLD);
            bentoBox.deposit(_token, address(bentoBox), to, amountLD, 0);
        } else {
            IERC20(_token).transfer(to, amountLD);
        }
    }
}
