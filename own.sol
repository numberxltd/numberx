pragma solidity ^0.4.24;

//import './library/SafeMath';

contract GameX {
    using SafeMath for uint256;
    string public name = "GameX";    // Contract name
    string public symbol = "nox";
    
    // dev setting
    address private comaddr = 0x00Ee2A090Ed7f6066F60C4e9936182fc4a1A6C29;
    mapping(address => bool) admins;
    bool public activated = false;
    uint public compot;
    
    // game setting
    uint minFee = 0.01 ether;
    uint maxFee = 1 ether;
    uint minLucky = 0.1 ether;
    uint retryfee = 0.1 ether;
    uint16 luckynum;
    uint lastnumtime = now;
    
    // one of seed
    uint private lastPlayer;
    
    uint public jackpot = 0; // current jackpot eth
    uint public maskpot = 0; // current maskpot eth
    uint public gameTotalGen = 0;
    
    uint public _iD;
    mapping(address => player) public player_;
    mapping(uint => address) public addrXid;
    
    struct player {
        uint16[] playerNum;  // card array
        uint16 playerTotal;  // sum of current round
        uint id;
        uint playerWin;      // win of current round
        uint playerGen;      // outcome of current round
        uint playerWinPot;   // eth in game wallet which can be withdrawed
        uint RetryTimes;     //
        uint lastRetryTime;  // last retry time , 6 hours int
        bool hasRetry;       //
        address Aff;         // referee address
        uint totalGen;
        bool hasAddTime;
    }
    
    constructor()
    {
        admins[address(msg.sender)] = true;
        admins[0x00Ee2A090Ed7f6066F60C4e9936182fc4a1A6C29] = true;
    }
    
    modifier isActivated() {
        require(activated, "not ready yet");
        _;
    }
    
    modifier isHuman() {
        address _addr = msg.sender;
        require(_addr == tx.origin);
        
        uint256 _codeLength;
        
        assembly {_codeLength := extcodesize(_addr)}
        require(_codeLength == 0, "sorry humans only");
        _;
    }
    
    modifier validAff(address _addr) {
        uint256 _codeLength;
        
        assembly {_codeLength := extcodesize(_addr)}
        require(_codeLength == 0, "sorry humans only");
        _;
    }
    
    modifier onlyOwner() {
        require(admins[msg.sender], "only admin");
        _;
    }
    
    // sorry if anyone send eth directly , it will going to the community pot
    function()
    public
    payable
    {
        compot += msg.value;
    }
    
    function getPlayerNum() constant public returns (uint16[]) {
        return player_[msg.sender].playerNum;
    }
    
    function getPlayerWin(address _addr) public view returns (uint, uint) {
        if (gameTotalGen == 0)
        {
            return (player_[_addr].playerWinPot, 0);
        }
        return (player_[_addr].playerWinPot, maskpot.mul(player_[_addr].totalGen).div(gameTotalGen));
    }
    
    function isLuckyGuy()
    private
    view
    returns (uint8)
    {
        if (player_[msg.sender].playerTotal == luckynum || player_[msg.sender].playerTotal == 100) {
            return 1;
        }
        
        if (player_[msg.sender].playerTotal <= 33 && player_[msg.sender].playerNum.length >= 3) {
            return 2;
        }
        return 0;
    }
    
    function Card(uint8 _num, bool _retry, address _ref)
    isActivated
    isHuman
    validAff(_ref)
    public
    payable
    {
        require(msg.value > 0);
        uint256 amount = msg.value;
        
        // if got another chance to fetch a card
        
        if (player_[msg.sender].id == 0)
        {
            _iD ++;
            player_[msg.sender].id = _iD;
            addrXid[_iD] = msg.sender;
        }
        
        // amount must be valid
        if (amount < minFee * _num || amount > maxFee * _num) {
            compot += amount;
            return;
        }
        
        if (player_[msg.sender].playerGen > 0)
        {
            // TODO 修改白皮书
            require(player_[msg.sender].playerGen * 3 >= msg.value);
        }
        
        if (_retry && _num == 1) {
            require(
                player_[msg.sender].playerNum.length > 0 &&
                player_[msg.sender].hasRetry == false && // not retry yet current round
                player_[msg.sender].RetryTimes > 0 && // must have a unused aff
                player_[msg.sender].lastRetryTime <= (now - 6 hours), // retry in max 4 times a day. 6 hours int
                'retry fee need to be valid'
            );
            
            player_[msg.sender].hasRetry = true;
            player_[msg.sender].RetryTimes --;
            player_[msg.sender].lastRetryTime == now;
            
            uint16 lastnum = player_[msg.sender].playerNum[player_[msg.sender].playerNum.length - 1];
            player_[msg.sender].playerTotal -= lastnum;
            player_[msg.sender].playerNum.length = player_[msg.sender].playerNum.length - 1;
            // flag for retry number
            player_[msg.sender].playerNum.push(100 + lastnum);
        }
        
        // jackpot got 1% of the amount
        jackpot += amount / 100;
        
        // update player gen pot
        player_[msg.sender].playerGen += amount - amount / 100;
        
        // if got a referee , add it
        // if ref valid, then add one more time
        if (
            player_[msg.sender].Aff == address(0x0) &&
            _ref != address(0x0) &&
            _ref != msg.sender &&
            player_[_ref].id > 0
        )
        {
            player_[msg.sender].Aff = _ref;
        }
        
        
        for (uint16 i = 1; i <= _num; i++) {
            uint16 x = randomX(i);
            
            // push x number to player current round and calculate it
            player_[msg.sender].playerNum.push(x);
            player_[msg.sender].playerTotal += x;
        }
        // random a number
        
        
        // lucky get jackpot 2-3%
        uint16 _case = isLuckyGuy();
        if (_case > 0) {
            //  win  3.6 * gen
            player_[msg.sender].playerWin = player_[msg.sender].playerGen * 36 / 10;
            
            if (amount >= minLucky) {
                uint jackwin;
                if (_case == 1) {
                    // 2% jackpot
                    jackwin = jackpot.div(50);
                    player_[msg.sender].playerWin += jackwin;
                    jackpot -= jackwin;
                }
                if (_case == 2) {
                    // 3% jackpot
                    jackwin = jackpot.mul(3).div(100);
                    player_[msg.sender].playerWin += jackwin;
                    jackpot -= jackwin;
                }
            }
            resetPlayer();
            return;
        }
        
        // reset Player if done
        if (player_[msg.sender].playerTotal > 100) {
            // 1% of current gen to com
            uint tocom = player_[msg.sender].playerGen.mul(1).div(100);
            //comaddr.transfer(tocom);
            compot += tocom;
            // rest 99% of cuurent gen to jackpot
            jackpot -= tocom;
            
            // clean current win
            player_[msg.sender].playerWin = 0;
            resetPlayer();
            return;
        }
        
        if (player_[msg.sender].playerTotal > 95) {
            // 2.5 gen
            player_[msg.sender].playerWin = player_[msg.sender].playerGen.mul(5).div(2);
            return;
        }
        
        if (player_[msg.sender].playerTotal > 85) {
            //  1.5 gen
            player_[msg.sender].playerWin = player_[msg.sender].playerGen.mul(3).div(2);
        }
    }
    
    event resultlog(address indexed user, uint16[] num, uint16 indexed total, uint gen, uint win, uint time);
    
    function resetPlayer()
    isActivated
    isHuman
    private
    {
        emit resultlog(
            msg.sender,
            player_[msg.sender].playerNum,
            player_[msg.sender].playerTotal,
            player_[msg.sender].playerGen,
            player_[msg.sender].playerWin,
            now
        );
        // reset
        player_[msg.sender].totalGen += player_[msg.sender].playerGen;
        gameTotalGen += player_[msg.sender].playerGen;
        if (
            player_[msg.sender].Aff != address(0x0) &&
            player_[msg.sender].hasAddTime == false &&
            player_[msg.sender].totalGen > retryfee
        ) {
            player_[player_[msg.sender].Aff].RetryTimes++;
            player_[player_[msg.sender].Aff].hasAddTime = true;
        }
        
        player_[msg.sender].playerGen = 0;
        
        player_[msg.sender].playerTotal = 0;
        
        player_[msg.sender].playerNum.length = 0;
        
        player_[msg.sender].hasRetry = false;
        
        // current win going to player win pot
        player_[msg.sender].playerWinPot += player_[msg.sender].playerWin;
        player_[msg.sender].playerWin = 0;
        
        if (luckynum == 0 || lastnumtime + 1 hours > now) {
            luckynum = randomX(luckynum);
            lastnumtime = now;
        }
    }
    
    function endRound()
    isActivated
    isHuman
    public
    {
        uint win = player_[msg.sender].playerWin;
        if (win > 0) {
            resetPlayer();
            return;
        }
        if (player_[msg.sender].playerTotal > 0 && player_[msg.sender].playerTotal <= 80) {
            uint gen = player_[msg.sender].playerGen;
            jackpot -= gen.div(3);
            player_[msg.sender].playerWin = gen.div(3);
            resetPlayer();
        }
    }
    
    function withdraw()
    isActivated
    isHuman
    public
    payable
    {
        (uint pot, uint dev) = getPlayerWin(msg.sender);
        uint amount = pot + dev;
        require(amount > 0, 'sorry not enough eth to withdraw');
        
        if (amount > address(this).balance)
            amount = address(this).balance;
        
        msg.sender.transfer(amount);
        player_[msg.sender].playerWinPot = 0;
        player_[msg.sender].totalGen = 0;
    }
    
    
    event randomlog(address addr, uint16 x);
    
    function randomX(uint16 _s)
    public
    returns (uint16)
    {
        uint16 x = uint16(keccak256(abi.encodePacked(
                (block.timestamp).add
                (block.difficulty).add
                ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (now)).add
                (block.gaslimit).add
                ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (now)).add
                (block.number).add
                (lastPlayer).add
                (gasleft()).add
                (_s)
            )));
        // change of the seed
        if (x > 50) {
            lastPlayer = player_[msg.sender].id;
        }
        x = x - ((x / 100) * 100);
        emit randomlog(msg.sender, x);
        return x;
    }
    
    // admin==================================
    function active()
    onlyOwner
    public
    {
        activated = true;
    }
    
    function setCom(address _addr)
    onlyOwner
    public
    {
        comaddr = _addr;
    }
    
    function setAdmin(address _addr)
    onlyOwner
    public
    {
        admins[_addr] = true;
    }
    
    function withCom(address _addr)
    onlyOwner
    public
    {
        uint _com = compot;
        if (address(this).balance < _com)
            _com = address(this).balance;
        
        _addr.transfer(_com);
    }
    
    function openJackPot(uint amount)
    onlyOwner
    public
    {
        require(amount <= jackpot);
        
        maskpot += amount;
        jackpot -= amount;
    }
}

library SafeMath {
    
    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b)
    internal
    pure
    returns (uint256 c)
    {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        require(c / a == b, "SafeMath mul failed");
        return c;
    }
    
    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }
    
    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b)
    internal
    pure
    returns (uint256)
    {
        require(b <= a, "SafeMath sub failed");
        return a - b;
    }
    
    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b)
    internal
    pure
    returns (uint256 c)
    {
        c = a + b;
        require(c >= a, "SafeMath add failed");
        return c;
    }
    
    /**
     * @dev gives square root of given x.
     */
    function sqrt(uint256 x)
    internal
    pure
    returns (uint256 y)
    {
        uint256 z = ((add(x, 1)) / 2);
        y = x;
        while (z < y)
        {
            y = z;
            z = ((add((x / z), z)) / 2);
        }
    }
    
    /**
     * @dev gives square. multiplies x by x
     */
    function sq(uint256 x)
    internal
    pure
    returns (uint256)
    {
        return (mul(x, x));
    }
    
    /**
     * @dev x to the power of y
     */
    function pwr(uint256 x, uint256 y)
    internal
    pure
    returns (uint256)
    {
        if (x == 0)
            return (0);
        else if (y == 0)
            return (1);
        else
        {
            uint256 z = x;
            for (uint256 i = 1; i < y; i++)
                z = mul(z, x);
            return (z);
        }
    }
}