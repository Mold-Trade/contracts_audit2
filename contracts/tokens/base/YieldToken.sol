// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "../../core/storage/YieldTokenStorage.sol";
import "../../libraries/Errors.sol";
contract YieldToken is YieldTokenStorage {
    constructor(string memory _name, string memory _symbol, uint256 _initialSupply) public {
        name = _name;
        symbol = _symbol;
        gov = msg.sender;
        admins[msg.sender] = true;
        _mint(msg.sender, _initialSupply);
    }
    function addAdmin(address _account) external onlyGov {
        admins[_account] = true;
    }
    function removeAdmin(address _account) external override onlyGov {
        admins[_account] = false;
    }
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }
    function addNonStakingAccount(address _account) external onlyAdmin {
        require(!nonStakingAccounts[_account], Errors.YIELDTOKEN_ACCOUNT_ALREADY_MARKED);
        _updateRewards(_account);
        nonStakingAccounts[_account] = true;
        nonStakingSupply = nonStakingSupply.add(balances[_account]);
    }
    function removeNonStakingAccount(address _account) external onlyAdmin {
        require(nonStakingAccounts[_account], Errors.YIELDTOKEN_ACCOUNT_NOT_MARKED);
        _updateRewards(_account);
        nonStakingAccounts[_account] = false;
        nonStakingSupply = nonStakingSupply.sub(balances[_account]);
    }
    function recoverClaim(address _account, address _receiver) external onlyAdmin {
        for (uint256 i = 0; i < yieldTrackers.length; i++) {
            address yieldTracker = yieldTrackers[i];
            IYieldTracker(yieldTracker).claim(_account, _receiver);
        }
    }
    function claim(address _receiver) external {
        for (uint256 i = 0; i < yieldTrackers.length; i++) {
            address yieldTracker = yieldTrackers[i];
            IYieldTracker(yieldTracker).claim(msg.sender, _receiver);
        }
    }
    /* settings*/
    function setGov(address _gov) external onlyGov {
        gov = _gov;
    }
    function setInfo(string memory _name, string memory _symbol) external onlyGov {
        name = _name;
        symbol = _symbol;
    }
    function setYieldTrackers(address[] memory _yieldTrackers) external onlyGov {
        yieldTrackers = _yieldTrackers;
    }
    function setInWhitelistMode(bool _inWhitelistMode) external onlyGov {
        inWhitelistMode = _inWhitelistMode;
    }
    function setWhitelistedHandler(address _handler, bool _isWhitelisted) external onlyGov {
        whitelistedHandlers[_handler] = _isWhitelisted;
    }
    /* views */
    function totalStaked() external view override returns (uint256) {
        return totalSupply.sub(nonStakingSupply);
    }
    function balanceOf(address _account) external view override returns (uint256) {
        return balances[_account];
    }
    function stakedBalance(address _account) external view override returns (uint256) {
        if (nonStakingAccounts[_account]) {
            return 0;
        }
        return balances[_account];
    }
    function transfer(address _recipient, uint256 _amount) external override returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }
    function allowance(address _owner, address _spender) external view override returns (uint256) {
        return allowances[_owner][_spender];
    }
    function approve(address _spender, uint256 _amount) external override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }
    function transferFrom(address _sender, address _recipient, uint256 _amount) external override returns (bool) {
        uint256 nextAllowance = allowances[_sender][msg.sender].sub(_amount, Errors.YIELDTOKEN_TRANSFER_AMOUNT_EXCEEDS_ALLOWANCE);
        _approve(_sender, msg.sender, nextAllowance);
        _transfer(_sender, _recipient, _amount);
        return true;
    }
    /*internal */
    function _mint(address _account, uint256 _amount) internal {
        require(_account != address(0), Errors.YIELDTOKEN_MINT_TO_THE_ZERO_ADDRESS);
        _updateRewards(_account);
        totalSupply = totalSupply.add(_amount);
        balances[_account] = balances[_account].add(_amount);
        if (nonStakingAccounts[_account]) {
            nonStakingSupply = nonStakingSupply.add(_amount);
        }
        emit Transfer(address(0), _account, _amount);
    }
    function _burn(address _account, uint256 _amount) internal {
        require(_account != address(0), Errors.YIELDTOKEN_BURN_FROM_THE_ZERO_ADDRESS);
        _updateRewards(_account);
        balances[_account] = balances[_account].sub(_amount, Errors.YIELDTOKEN_BURN_AMOUNT_EXCEEDS_BALANCE);
        totalSupply = totalSupply.sub(_amount);
        if (nonStakingAccounts[_account]) {
            nonStakingSupply = nonStakingSupply.sub(_amount);
        }
        emit Transfer(_account, address(0), _amount);
    }
    function _transfer(address _sender, address _recipient, uint256 _amount) private {
        require(_sender != address(0), Errors.YIELDTOKEN_TRANSFER_FROM_THE_ZERO_ADDRESS);
        require(_recipient != address(0), Errors.YIELDTOKEN_TRANSFER_TO_THE_ZERO_ADDRESS);
        if (inWhitelistMode) {
            require(whitelistedHandlers[msg.sender], Errors.YIELDTOKEN_MSG_SENDER_NOT_WHITELISTED);
        }
        _updateRewards(_sender);
        _updateRewards(_recipient);
        balances[_sender] = balances[_sender].sub(_amount, Errors.YIELDTOKEN_TRANSFER_AMOUNT_EXCEEDS_BALANCE);
        balances[_recipient] = balances[_recipient].add(_amount);
        if (nonStakingAccounts[_sender]) {
            nonStakingSupply = nonStakingSupply.sub(_amount);
        }
        if (nonStakingAccounts[_recipient]) {
            nonStakingSupply = nonStakingSupply.add(_amount);
        }
        emit Transfer(_sender, _recipient, _amount);
    }
    function _approve(address _owner, address _spender, uint256 _amount) private {
        require(_owner != address(0), Errors.YIELDTOKEN_APPROVE_FROM_THE_ZERO_ADDRESS);
        require(_spender != address(0), Errors.YIELDTOKEN_APPROVE_TO_THE_ZERO_ADDRESS);
        allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }
    function _updateRewards(address _account) private {
        for (uint256 i = 0; i < yieldTrackers.length; i++) {
            address yieldTracker = yieldTrackers[i];
            IYieldTracker(yieldTracker).updateRewards(_account);
        }
    }
}
