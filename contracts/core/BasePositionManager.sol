// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "./settings/BasePositionManagerSettings.sol";
contract BasePositionManager is BasePositionManagerSettings {
    constructor(address _vault, address _router, address _shortsTracker, address _weth, uint256 _depositFee) public {
        vault = _vault;
        router = _router;
        weth = _weth;
        depositFee = _depositFee;
        shortsTracker = _shortsTracker;
        admin = msg.sender;
    }
    function withdrawFees(address _token, address _receiver) external onlyAdmin {
        uint256 amount = feeReserves[_token];
        if (amount == 0) {return;}
        feeReserves[_token] = 0;
        IERC20(_token).safeTransfer(_receiver, amount);
        emit Events.WithdrawFees(_token, _receiver, amount);
    }

    function approve(address _token, address _spender, uint256 _amount) external onlyGov {
        IERC20(_token).approve(_spender, _amount);
    }

    function sendValue(address payable _receiver, uint256 _amount) external onlyGov {
        _receiver.sendValue(_amount);
    }
}
