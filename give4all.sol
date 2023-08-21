/**
 *Submitted for verification at Etherscan.io on 2023-08-21
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract ERC20 is Context, IERC20 {
    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    constructor (string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }
    function name() public view virtual returns (string memory) {
        return _name;
    }
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }
    function decimals() public view virtual returns (uint8) {
        return 18;
    }
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address account) public view virtual override returns (uint256) {
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

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);

        return true;
    }
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}

contract GFAToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 10 ** 6 * 10 ** uint(decimals()));
    }
}

contract Project {
    event Donate(address indexed user, uint amountToken);
    event VoteFor(address indexed user, uint weight);
    event VoteAgainst(address indexed user, uint weight);

    enum StatusEnum {
        WAITING,
        APPROVE,
        DENY,
        DELETED,
        ENDED
    }

    address owner;
    int locked = 1;

    // Project infomation
    address public author; 
    string public title; 
    string public description; 
    uint public raised; 
    uint public createAt; 
    uint public expiresAt;  
    uint public amountTokenDeposit; 
    StatusEnum public status; 
    uint public amountTokenDonate;
    mapping(address => uint) public donationOf;
    mapping(address => bool) public isWithdraw;

    // Weight
    uint public forWeight;
    uint public againstWeight;
    mapping(address => uint) public weightOf;
    mapping(address => uint) public isVote; // 0: chưa vote, 1: vote for, 2: vote against

    constructor(
        string memory _title,
        string memory _description,
        uint _raised,
        uint _expiresAt,
        address _author,
        uint _amountTokenDeposit
    ){
        title = _title;
        description = _description;
        raised = _raised;
        expiresAt = _expiresAt;
        author = _author;
        createAt = block.timestamp;
        owner = msg.sender;
        if(_amountTokenDeposit > 0){
            amountTokenDeposit = _amountTokenDeposit;
            isVote[author] = 1;
            weightOf[author] = _amountTokenDeposit;
            forWeight = _amountTokenDeposit;
        }
    }

    modifier onlyCallFromContract(){
        require(msg.sender == owner, "Not call from contract");
        _;
    }

    modifier projectExpired(){
        require(expiresAt >= block.timestamp, "Project has expired");
        _;
    }

    modifier noReentrant() {
        require(locked == 1, "No re-entrancy");
        locked = 2;
        _;
        locked = 1;
    }

    function approve() external onlyCallFromContract projectExpired{
        require(status == StatusEnum.WAITING, "Status project is not waiting status");
        status = StatusEnum.APPROVE;
    }
    function deny(address tokenAddress) external onlyCallFromContract projectExpired{
        require(status == StatusEnum.WAITING, "Status project is not waiting status");
        if(amountTokenDeposit > 0){
            GFAToken token = GFAToken(tokenAddress);
            token.transfer(author, amountTokenDeposit);
        }
        status = StatusEnum.DENY;
    }
    function deleteProject(address user, address tokenAddress) external onlyCallFromContract projectExpired{
        require(status == StatusEnum.WAITING, "Status project is not waiting status");
        require(user == author, "Not permission");
        if(amountTokenDeposit > 0){
            GFAToken token = GFAToken(tokenAddress);
            token.transfer(author, amountTokenDeposit);
        }
        status = StatusEnum.DELETED;
    }

    function donate(uint amountToken, uint weight, address user) external onlyCallFromContract projectExpired{
        require(isVote[user] != 2, "You were against the project");
        require(status == StatusEnum.APPROVE, "Status project is not approve status");
        amountTokenDonate += amountToken;
        donationOf[user] += amountToken;
        if(isVote[user] == 0){
            isVote[user] = 1;
            forWeight += weight;
            weightOf[user] = weight;
        }
        emit Donate(user, amountToken);
        emit VoteFor(user, weight);
    }

    function voteFor(uint weight, address user) external onlyCallFromContract projectExpired{
        require(isVote[user] == 0, "You were voted the project");
        require(status == StatusEnum.APPROVE, "Status project is not approve status");
        isVote[user] = 1;
        forWeight += weight;
        weightOf[user] = weight;
        emit VoteFor(user, weight);
    }

    function voteAgainst(uint weight, address user) external onlyCallFromContract projectExpired{
        require(isVote[user] == 0, "You were voted the project");
        require(status == StatusEnum.APPROVE, "Status project is not approve status");
        isVote[user] = 2;
        againstWeight += weight;
        weightOf[user] = weight;
        emit VoteAgainst(user, weight);
    }

    function withdrawByAuthor(address user, address tokenAddress) external onlyCallFromContract noReentrant{
        require(status == StatusEnum.APPROVE, "Status project is not approve status");
        require(user == author, "Not permission");
        require(amountTokenDonate >= raised, "Project has not enough donation");
        require(expiresAt <= block.timestamp, "Project has not expired");
        require(forWeight > againstWeight, "Project were against");
        GFAToken token = GFAToken(tokenAddress);
        token.transfer(user, amountTokenDonate + amountTokenDeposit);
        status = StatusEnum.ENDED;
    }

    function withdrawDeposit(address user, address tokenAddress) external onlyCallFromContract noReentrant{
        require(status == StatusEnum.APPROVE, "Status project is not approve status");
        require(user == author, "Not permission");
        require(expiresAt <= block.timestamp, "Project has not expired");
        require(amountTokenDonate < raised || forWeight <= againstWeight, "Not enough condition");
        require(amountTokenDeposit > 0, "You don't deposit");
        GFAToken token = GFAToken(tokenAddress);
        token.transfer(user, amountTokenDeposit);
        status = StatusEnum.ENDED;
    }

    function withdrawFromProjectByDonor(address user, address tokenAddress) external onlyCallFromContract noReentrant{
        require(status == StatusEnum.APPROVE, "Status project is not approve status");
        require(expiresAt <= block.timestamp, "Project has not expired");
        require(amountTokenDonate < raised || forWeight <= againstWeight, "Not enough condition");
        require(donationOf[user] > 0, "You don't donate");
        require(isWithdraw[user] == false, "You withdrawed");
        GFAToken token = GFAToken(tokenAddress);
        token.transfer(user, donationOf[user]);
        isWithdraw[user] = true;
    }
}

contract Give4All {
    event BuyToken(address indexed buyer, uint amount);
    event AddAdmin(address indexed user);

    GFAToken public token;
    uint tokenPrice = 10 ** 14;
    mapping(address => bool) isAdmin;
    Project[] public projects;
    uint public projectCount;

    int locked = 1;
    constructor(){
        bytes memory bytecode = type(GFAToken).creationCode;
        bytes memory code = abi.encodePacked(bytecode, abi.encode("Give4All", "GFA"));
        address addr;
        assembly {
            addr := create(callvalue(), add(code, 0x20), mload(code))
        }
        require(addr != address(0), "deploy failed");
        token = GFAToken(addr);
        isAdmin[msg.sender] = true;
    }

    modifier noReentrant() {
        require(locked == 1, "No re-entrancy");
        locked = 2;
        _;
        locked = 1;
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Not permission");
        _;
    }

    function addAdmin(address user) external onlyAdmin{
        require(!isAdmin[user], "User is admin");
        isAdmin[msg.sender] = true;
        emit AddAdmin(user);
    }

    function getAmountTokenInPool() external view returns(uint){
        return token.balanceOf(address(this));
    }

    function buyToken() external payable noReentrant{
        require(msg.value >= tokenPrice, "You need to buy at least 1 token");
        unchecked{
            uint amountToken = msg.value * 10 ** token.decimals() / tokenPrice;
            require(amountToken <= token.balanceOf(address(this)), "The amount of tokens is not enough");
            token.transfer(msg.sender, amountToken);
            emit BuyToken(msg.sender, amountToken);
        }
    } 

    function createProject(
        string memory _title,
        string memory _description,
        uint _raised,
        uint _expiresAt,
        uint _amountTokenDeposit) external {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_expiresAt > block.timestamp, "Expiry date not valid");
        require(_raised > 0, "Donation limit is larger than 0");
        uint amountTokenDeposit = _amountTokenDeposit * token.decimals();
        Project project = new Project(
            _title, _description, _raised,
            _expiresAt, msg.sender,
            amountTokenDeposit
        );
        projects.push(project);
        ++projectCount;
        if(amountTokenDeposit > 0){
            bool success = token.transferFrom(msg.sender, address(project), amountTokenDeposit);
            require(success, "Transfer fail");
        }
    }

    function getProjects() external view returns(Project[] memory){
        return projects;
    }

    function approve(Project project) external onlyAdmin{
        project.approve();
    }

    function deny(Project project) external onlyAdmin{
        project.deny(address(token));
    }

    function deleteProject(Project project) external{
        project.deleteProject(msg.sender, address(token));
    }

    function donate(Project project, uint amountToken) external{
        require(amountToken > 0, "Donate at least 1 token");
        uint weight = token.balanceOf(msg.sender);
        bool success = token.transferFrom(msg.sender, address(project), amountToken * token.decimals());
        require(success, "Transfer fail");
        project.donate(amountToken, weight, msg.sender);
    }

    function voteFor(Project project) external {
        uint weight = token.balanceOf(msg.sender);
        project.voteFor(weight, msg.sender);
    }

    function voteAgainst(Project project) external {
        uint weight = token.balanceOf(msg.sender);
        project.voteAgainst(weight, msg.sender);
    }

    function withdrawByAuthor(Project project) external {
        project.withdrawDeposit(msg.sender, address(token));
    }

    function withdrawDeposit(Project project) external {
        project.withdrawDeposit(msg.sender, address(token));
    }

    function withdrawFromProjectByDonor(Project project) external {
        project.withdrawFromProjectByDonor(msg.sender, address(token));
    }
}
