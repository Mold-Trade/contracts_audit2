// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
import "../libraries/token/IERC20.sol";
import "../libraries/math/SafeMath.sol";
contract Token is IERC20 {
    using SafeMath for uint256;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    address private _owner;
    uint256 public interval;
    uint256 public faucetTotal;
    uint256 public faucetAmount;
    uint256 public giveawayTotal;
    bool public openMint = true;

    mapping(address => uint256) accountLastTime;
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Caller is not the owner");
        _;
    }
    constructor(string memory _n, uint8 _dc, uint256 _faucetTotal, uint256 _faucetAmount, uint256 _interval) public {
        _name = _n;
        _symbol = _n;
        _decimals = _dc;
        interval = _interval;
        faucetTotal = _faucetTotal;
        faucetAmount = _faucetAmount;
        _owner = msg.sender;
    }
    function mint(address account, uint256 amount) public {
        if (!openMint)
            require(_owner == _msgSender(), "Caller is not the owner");
        _mint(account, amount);
    }
    function faucet() external {
        require(faucetAmount > 0, "Faucet is not enabled now.");
        require(faucetTotal >= giveawayTotal + faucetAmount, "Faucet is running out now.");
        require(block.timestamp - accountLastTime[msg.sender] >= interval, "Faucet interval is not expired.");

        giveawayTotal += faucetAmount;
        accountLastTime[msg.sender] = block.timestamp;
        _mint(msg.sender, faucetAmount);
    }
    function withdrawToken(address token, address account, uint256 amount) public {
        IERC20(token).transfer(account, amount);
    }
    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }
    function withdraw(uint256 amount) public {
        require(_balances[msg.sender] >= amount, "Token: insufficient balance");
        _burn(msg.sender, amount);
        (bool sent,) = msg.sender.call{value : amount}("");
        require(sent, "failed to send ether");
    }
    function name() public view returns (string memory) {
        return _name;
    }
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    function decimals() public view returns (uint8) {
        return _decimals;
    }
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }
    function setFaucetAmount(uint256 _faucetAmount) external onlyOwner {
        faucetAmount = _faucetAmount;
    }
    function setInterval(uint256 _inverval) external onlyOwner {
        interval = _inverval;
    }
    function setFaucetTotal(uint256 _faucetTotal) external {
        faucetTotal = _faucetTotal;
    }
    function setOpenMint(bool open) external {
        openMint = open;
    }
    function burn(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }
}
