// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.11;

import "./interfaces/IBentoboxBridgeStargate.sol";

contract BentoboxBridgeStargate is
    IBentoboxBridgeStargate,
    IStargateReceiver,
    BoringBatchable
{
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
    ) external override {
        bentoBox.setMasterContractApproval(
            user,
            address(this),
            approved,
            v,
            r,
            s
        );
    }

    function approveToStargateRouter(IERC20 token) external override {
        token.approve(address(stargateRouter), type(uint256).max);
    }

    function teleport(BridgeParams memory bridgeParams)
        external
        payable
        override
    {
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

        emit Teleported(msg.sender, bridgeParams.token, bridgeParams.amount);
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

        emit Received(to, _token, amountLD);
    }
}
