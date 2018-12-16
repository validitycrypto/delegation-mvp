pragma solidity ^0.4.24;

import "./SafeMath.sol";

contract ERC20d {

    using SafeMath for uint;

    bytes32 constant POS = 0x506f736974697665000000000000000000000000000000000000000000000000;
    bytes32 constant NEU = 0x6e65757472616c00000000000000000000000000000000000000000000000000;
    bytes32 constant NEG = 0x4e65676174697665000000000000000000000000000000000000000000000000;

    struct _delegate {
        bytes32 _delegationIdentity;
        bytes32 _positiveVotes;
        bytes32 _negativeVotes;
        bytes32 _neutralVotes;
        bytes32 _totalEvents;
        bytes32 _totalVotes;
        bytes32 _trustLevel;
    }

    mapping (address => mapping (address => uint)) private _allowed;
    mapping (address => uint) private _balances;
    mapping (bytes => _delegate) private _stats;
    mapping (bytes => address) private _wallet;
    mapping (address => bool) private _active;
    mapping (address => bool) private _stake;
    mapping (address => bytes) private _vID;
    mapping (bytes => uint) private _trust;

    address private _founder = msg.sender;
    address private _admin = address(0x0);

    uint private _totalSupply;
    uint private _maxSupply;

    string private _name;
    string private _symbol;
    uint private _decimals;

    modifier _stakeCheck(address _from , address _to) {
        require(!isStaking(_from) && !isStaking(_to));
        _;
    }

    modifier _verifyID(address _account) {
        if(!_active[_account]) {
            createvID(_account);
        }
        _;
    }

    modifier _trustLimit(bytes _id) {
        if(_trust[_id] < block.number) {
           _trust[_id] = block.number.add(100);
        } else {
           revert();
        }
        _;
    }

    modifier _onlyAdmin() {
        require(msg.sender == _admin);
        _;
    }

    modifier _onlyFounder() {
        require(msg.sender == _founder);
        _;
    }

    constructor() public {
        // 50,600,000,000 VLDY - Max supply
        // 48,070,000,000 VLDY - Initial supply
        //  2,530,000,000 VLDY - Delegation supply
        uint genesis = uint(48070000000).mul(10**uint(18));
        _maxSupply = uint(50600000000).mul(10**uint(18));
        _mint(_founder, genesis);
        _name = "Validity";
        _symbol = "VLDY";
        _decimals = 18;
    }

    function initiateStake() public {
        require(!isStaking(msg.sender));
        require(isActive(msg.sender));

        _stake[msg.sender] = true;
        emit Stake(msg.sender);
    }

    function setIdentity(bytes32 _identity) public {
        require(_active[msg.sender]);

        bytes storage id = _vID[msg.sender];
        _stats[id]._delegationIdentity = _identity;
    }

    function adminControl(address _entity) public _onlyFounder {
        _admin = _entity;
    }

    function totalSupply() public view returns (uint total) {
        total = _totalSupply;
    }

    function maxSupply() public view returns (uint max) {
        max = _maxSupply;
    }

    function balanceOf(address _owner) public view returns (uint) {
        return _balances[_owner];
    }

    function getvID(address _account) public view returns (bytes id) {
        id = _vID[_account];
    }

    function getIdentity(bytes _id) public view returns (bytes32 identity) {
        identity = _stats[_id]._delegationIdentity;
    }

    function getAddress(bytes _id) public view returns (address account) {
        account = _wallet[_id];
    }

    function trustLevel(bytes _id) public view returns (uint level) {
        level = uint(_stats[_id]._trustLevel);
    }

    function isActive(address _account)  public view returns (bool) {
        return _active[_account];
    }

    function isStaking(address _account)  public view returns (bool) {
        return _stake[_account];
    }

    function totalEvents(bytes _id) public view returns (uint count) {
        count = uint(_stats[_id]._totalEvents);
    }

    function totalVotes(bytes _id) public view returns (uint total) {
        total = uint(_stats[_id]._totalVotes);
    }

    function positiveVotes(bytes _id) public view returns (uint positive) {
        positive = uint(_stats[_id]._positiveVotes);
    }

    function negativeVotes(bytes _id) public view returns (uint negative) {
        negative = uint(_stats[_id]._negativeVotes);
    }

     function neutralVotes(bytes _id) public view returns (uint neutral) {
        neutral = uint(_stats[_id]._neutralVotes);
    }

    function allowance(address _owner, address _spender) public view returns (uint) {
        return _allowed[_owner][_spender];
    }

    function transfer(address _to, uint _value) public returns (bool) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint _value) public returns (bool) {
        require(_allowed[msg.sender][_spender] == uint(0));
        require(_spender != address(0x0));

        _allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function _mint(address _account, uint _value) _verifyID(_account) internal {
        require(_totalSupply.add(_value) <= _maxSupply);
        require(_account != address(0x0));

        _totalSupply = _totalSupply.add(_value);
        _balances[_account] = _balances[_account].add(_value);
        emit Transfer(address(0x0), _account, _value);
    }

    function transferFrom(address _from, address _to, uint _value) public returns (bool) {
        _allowed[_from][msg.sender] = _allowed[_from][msg.sender].sub(_value);
        _transfer(_from, _to, _value);
        emit Approval(_from, msg.sender, _allowed[_from][msg.sender]);
        return true;
    }

    function increaseAllowance(address _spender, uint _addedValue) public returns (bool) {
        require(_spender != address(0x0));

        _allowed[msg.sender][_spender] = _allowed[msg.sender][_spender].add(_addedValue);
        emit Approval(msg.sender, _spender, _allowed[msg.sender][_spender]);
        return true;
    }

    function decreaseAllowance(address _spender, uint _subtractedValue) public returns (bool) {
        require(_spender != address(0x0));

        _allowed[msg.sender][_spender] = _allowed[msg.sender][_spender].sub(_subtractedValue);
        emit Approval(msg.sender, _spender, _allowed[msg.sender][_spender]);
        return true;
    }

     function _transfer(address _from, address _to, uint _value) _stakeCheck(_from, _to) _verifyID(_to) internal {
        require(_to != address(0x0));

        _balances[_from] = _balances[_from].sub(_value);
        _balances[_to] = _balances[_to].add(_value);
        emit Transfer(_from, _to, _value);
    }

    function delegationReward(bytes _id, address _account, uint _reward) public _onlyAdmin {
        require(isStaking(_account));

        _stake[_account] = false;
        _mint(_account, _reward);
        emit Reward(_id, _reward);
    }

    function delegationEvent(bytes _id, bytes32 _choice, uint _weight) public _onlyAdmin {
        require(_choice == POS || _choice == NEU || _choice == NEG);

        _stake[_wallet[_id]] = true;
        _delegate storage x = _stats[_id];
        if(_choice == POS) {
            x._positiveVotes = bytes32(positiveVotes(_id).add(_weight));
        } else if(_choice == NEU) {
            x._neutralVotes = bytes32(neutralVotes(_id).add(_weight));
        } else if(_choice == NEG) {
            x._negativeVotes = bytes32(negativeVotes(_id).add(_weight));
        }
        x._totalVotes = bytes32(totalVotes(_id).add(_weight));
        x._totalEvents = bytes32(totalEvents(_id).add(1));
    }

    function delegationIdentifier(address _account) internal view returns (bytes id) {
        bytes memory stamp = bytesStamp(block.timestamp);
        bytes32 prefix = 0x56616c6964697479;
        bytes32 x = bytes32(_account);
        id = new bytes(32);
        for(uint v = 0; v < id.length; v++){
            uint prefixIndex = 24 + v;
            uint timeIndex = 20 + v;
            if(v < 8){
                id[v] = prefix[prefixIndex];
            } else if(v < 12){
                id[v] = stamp[timeIndex];
            } else {
                id[v] = x[v];
            }
        }
    }

    function increaseTrust(bytes _id) _trustLimit(_id) _onlyAdmin public {
        _stats[_id]._trustLevel = bytes32(trustLevel(_id).add(1));
        emit Trust(_id, POS);
    }

    function decreaseTrust(bytes _id) _trustLimit(_id) _onlyAdmin public {
        _stats[_id]._trustLevel = bytes32(trustLevel(_id).add(1));
        emit Trust(_id, NEG);
    }

    function bytesStamp(uint _x) internal pure returns (bytes b) {
        b = new bytes(32);
        assembly {
            mstore(add(b, 32), _x)
        }
    }

    function createvID(address _account) internal {
         bytes memory id = delegationIdentifier(_account);
         emit Neo(_account, id, block.number);
         _active[_account] = true;
         _wallet[id] = _account;
         _vID[_account] = id;
    }

    event Approval(address indexed owner, address indexed spender, uint value);

    event Transfer(address indexed from, address indexed to, uint value);

    event Neo(address indexed subject, bytes vID, uint block);

    event Reward(bytes vID, uint reward);

    event Trust(bytes vID, bytes32 flux);

    event Stake(address indexed staker);

}
