pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

contract GambleChannel {
    bool public Finalized;
    bool public Adjusted;
    uint public ClosingBlock;
    uint public FinalNonce;
    bool public FinalBettor;
    uint public Betsize;
    mapping(bool => address) public players;
    mapping(address => uint) public deposits;
    mapping(address => int) public deltas;

    struct Bet { 
        bytes32 Priorhash; 
        bytes32 Currhash; 
        bool Bettor; 
        int Balance0; 
        int Balance1; 
        uint Nonce; 
        uint8 v; 
        bytes32 r; 
        bytes32 s;
    }

    modifier deposit() {
        if (players[true] != msg.sender && 
            players[false] != msg.sender){ revert();}
        deposits[msg.sender] += msg.value;
        _;
    }

    function() external payable deposit { }

    event ChannelClosed();

    function gambleChannel (address player2, uint betsize) deposit public payable  {
        if (msg.sender == player2) {revert();}
        players[true] = msg.sender;
        players[false] = player2;
        Betsize = betsize;
        Finalized = false;
        Adjusted = false;
    }
    
    function generateRandomBit() private view returns(bool) {
        return now %2 == 0;
    }

    function checksig(Bet memory b) private view returns(bool) {
        bytes32 hash = keccak256(abi.encodePacked(b.Priorhash, b.Currhash, b.Bettor, b.Balance0, b.Balance1, b.Nonce));
        address player = players[b.Bettor];
        return player == ecrecover(hash, b.v, b.r, b.s);
    }
        
    function checkpair(Bet memory curr, Bet memory prior) view private returns(bool) {
        
        if (!checksig(curr)) return false;
        if (!checksig(prior)) return false;

        
        if (curr.Bettor == prior.Bettor) return false;

        
        if (curr.Currhash != prior.Priorhash) return false;

        
        if (curr.Priorhash != prior.Currhash) return false;

        
        if (curr.Nonce != prior.Nonce + 1) return false;

        bool winner = generateRandomBit();

        int trueChange = int(-Betsize);
        int falseChange = int(Betsize);
        if (winner) {
            trueChange = int(Betsize);
            falseChange = int(-Betsize);
        }
        if (curr.Balance0 != prior.Balance0 + falseChange) return false;
        if (curr.Balance1 != prior.Balance1 + trueChange) return false;

        
        return true;
    }

    function setFinal(Bet memory bet) private {
        address player0 = players[false];
        address player1 = players[true];
        deltas[player0] = bet.Balance0; 
        deltas[player1] = bet.Balance1;
        FinalNonce = bet.Nonce;
        FinalBettor = bet.Bettor;
        ClosingBlock = block.number + 1;
        if (!Finalized) Finalized = true;
    }

    function finalize(Bet memory currentBet, Bet memory priorBet) public payable deposit {
        if (!checkpair( currentBet,  priorBet)) {revert();}
        if (!Finalized || currentBet.Nonce > FinalNonce) setFinal(currentBet);
    }

    function claim() public deposit payable{
        if (channelClosed()) {
            if (!Adjusted) {
         
                if (FinalBettor) {
                    deltas[players[true]] += int(Betsize);
                    deltas[players[false]] -= int(Betsize);
                } else {
                    deltas[players[true]] -= int(Betsize);
                    deltas[players[false]] += int(Betsize);
                }
                Adjusted = true;
            }
            uint256 amount = deposits[msg.sender] + uint(deltas[msg.sender]);
            if (amount > 0) {
                deposits[msg.sender] = 0;
                deltas[msg.sender] = 0;
                if (!msg.sender.send(amount)) {revert();}
            }
        }
    }

    function channelClosed() view private returns(bool) {
        return Finalized && block.number > ClosingBlock ;
    }
}