// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

contract Give4All {
    address public owner;
    uint public projectTax; // Wei
    uint public projectCount;
    projectStruct[] projects;
    uint locked = 1;

    mapping(uint256 => rateStruct[]) rateOf;
    mapping(uint256 => mapping(address=>bool)) votedExisted;
    mapping(uint256 => donationStruct[]) donationOf;

    enum statusEnum {
        OPEN,
        WITHDRAWED,
        REFUNDED,
        DELETED
    }

    struct projectStruct {
        uint id;
        address owner;
        string title;
        string description;
        string imageURL;
        uint raised;
        uint createAt;
        uint expiresAt;
        uint balanceOf;
        string[] tags;
        statusEnum status;
    }

    struct donationStruct {
        address donor;
        uint donationTime;
        uint value;
    }

    struct rateStruct {
        address user;
        uint donationTime;
        uint score;
    }

    modifier ownerOnly(){
        require(msg.sender == owner, "Owner reserved only");
        _;
    }

    modifier authorOnly(uint projectId){
        require(msg.sender == projects[projectId].owner, "Unauthorized Entity");
        _;
    }

    modifier projectIsOpen(uint projectId){
        require(projectId < projectCount, "Project not found");
        require(projects[projectId].status == statusEnum.OPEN, "Project no longer opened");
        require(projects[projectId].expiresAt > block.timestamp, "Project has expired");
        _;
    }

    event Action (
        uint256 id,
        string actionType,
        address indexed executor,
        uint256 timestamp
    );

    constructor(uint _projectTax) {
        owner = msg.sender;
        projectTax = _projectTax;
    }

    function createProject(
        string calldata title,
        string calldata description,
        string calldata imageURL,
        uint raised,
        uint expiresAt,
        string[] memory tags
    ) public payable returns (bool) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(bytes(imageURL).length > 0, "ImageURL cannot be empty");
        require(expiresAt > block.timestamp, "Expiry date not valid");
        require(raised > 0, "Donation limit is larger than 0");
        require(msg.value >= projectTax, "You need to spend more ETH!");

        projectStruct memory project;
        project.id = projectCount;
        project.owner = msg.sender;
        project.title = title;
        project.description = description;
        project.imageURL = imageURL;
        project.raised = raised;
        project.createAt = block.timestamp;
        project.expiresAt = expiresAt;
        project.tags = tags;
        project.balanceOf += (msg.value - projectTax);
        donationOf[projectCount].push(donationStruct(msg.sender, block.timestamp, msg.value - projectTax));

        projects.push(project);
        ++projectCount;

        emit Action (
            projectCount,
            "PROJECT CREATED",
            msg.sender,
            block.timestamp
        );
        return true;
    }

    function updateProject(
        uint id,
        string calldata title,
        string calldata description,
        string calldata imageURL,
        uint raised,
        uint expiresAt,
        string[] memory tags
    ) public projectIsOpen(id) authorOnly(id) returns (bool) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(bytes(imageURL).length > 0, "ImageURL cannot be empty");
        require(expiresAt > block.timestamp, "Expiry date not valid");
        require(raised > 0, "Donation limit is larger than 0");

        projectStruct storage project = projects[id];
        project.id = projectCount;
        project.owner = msg.sender;
        project.title = title;
        project.description = description;
        project.imageURL = imageURL;
        project.raised = raised;
        project.expiresAt = expiresAt;
        project.tags = tags;

        emit Action (
            id,
            "PROJECT UPDATED",
            msg.sender,
            block.timestamp
        );

        return true;
    }

    function donation(uint id) public payable projectIsOpen(id) returns (bool){
        require(msg.value >= projectTax, "You need to spend more ETH!");

        projects[id].balanceOf += msg.value - projectTax;
        donationOf[id].push(donationStruct(msg.sender, block.timestamp, msg.value - projectTax));
        
        emit Action (
            id,
            "PROJECT DONATION",
            msg.sender,
            block.timestamp
        );
        return true;
    }

    function rate(uint id, uint score) public projectIsOpen(id) returns (bool){
        require(score <= 5, "Score not valid");
        if(votedExisted[id][msg.sender]){
            rateStruct[] memory arr = rateOf[id];
            uint len = arr.length;
            for(uint i = 0; i < len; ){
                if(arr[i].user == msg.sender){
                    rateOf[id][i].score = score;
                    break;
                }
                unchecked {
                    ++i;
                }
            }
        }
        else{
            rateOf[id].push(rateStruct(msg.sender, block.timestamp, score));
            votedExisted[id][msg.sender] = true;
        }
            
        
        emit Action (
            id,
            "PROJECT RATED",
            msg.sender,
            block.timestamp
        );
        return true;
    }

    function deleteProject(uint id) public projectIsOpen(id) authorOnly(id) returns (bool) {
        require(locked == 1, "System is locked");
        locked = 2;
        projects[id].status = statusEnum.DELETED;
        donationStruct[] memory arr = donationOf[id];
        uint len = arr.length;
        for(uint i = 0; i < len; ){
            (bool callSuccess, ) = payable(arr[i].donor).call{value: arr[i].value}("");
            require(callSuccess, "Call failed");
            ++i;
        }
        locked = 1;

        emit Action (
            id,
            "PROJECT DELETED",
            msg.sender,
            block.timestamp
        );
        return true;
    }

    function changeTax(uint _taxPct) public ownerOnly {
        projectTax = _taxPct;
    }

    function getProject(uint id) public view returns (projectStruct memory) {
        require(id < projectCount, "Project not found");
        return projects[id];
    }
    
    function getProjects() public view returns (projectStruct[] memory) {
        return projects;
    }

    function getDonations(uint id) public view returns(donationStruct[] memory){
        require(id < projectCount, "Project not found");
        return donationOf[id];
    }

    function getRates(uint id) public view returns(rateStruct[] memory){
        require(id < projectCount, "Project not found");
        return rateOf[id];
    }

    function withdrawFromProject(uint id) public payable{
        require(id < projectCount, "Project not found");
        require(msg.sender == projects[id].owner, "Unauthorized Entity");
        require(projects[id].status == statusEnum.OPEN, "Project no longer opened");
        require(projects[id].balanceOf >= projects[id].raised, "Project has not enough donation");
        require(projects[id].expiresAt <= block.timestamp, "Project has not expired");
        projectStruct storage project = projects[id];
        project.status = statusEnum.WITHDRAWED;
        (bool callSuccess, ) = payable(msg.sender).call{value: projects[id].balanceOf}("");
        require(callSuccess, "Call failed");
        project.balanceOf = 0;
    }
}
