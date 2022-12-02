pragma solidity ^0.6;

import "../../lib/SafeMath.sol";

import {Classifier64} from "./classification/Classifier.sol";
import {DataHandler64} from "./data/DataHandler.sol";
import {IncentiveMechanism64} from "./incentive/IncentiveMechanism.sol";

/**
 * The main interface to sharing updatable models on the blockchain.
 */
contract CollaborativeTrainer {
    string public name;
    string public description;
    string public encoder;

    constructor(
        string memory _name,
        string memory _description,
        string memory _encoder
    ) public {
        name = _name;
        description = _description;
        encoder = _encoder;
    }
}

contract CollaborativeTrainer64 is CollaborativeTrainer {
    using SafeMath for uint256;

    /** Data has been added. */
    event AddData(
        /**
         * The data stored.
         */
        int64[] d,
        /**
         * The classification for the data.
         */
        uint64 c,
        /**
         * The time it was added.
         */
        uint t,
        /**
         * The address that added the data.
         */
        address indexed sender,
        uint cost
    );

    DataHandler64 public dataHandler;
    IncentiveMechanism64 public incentiveMechanism;
    Classifier64 public classifier;

    constructor(
        string memory _name,
        string memory _description,
        string memory _encoder,
        DataHandler64 _dataHandler,
        IncentiveMechanism64 _incentiveMechanism,
        Classifier64 _classifier
    ) public CollaborativeTrainer(_name, _description, _encoder) {
        dataHandler = _dataHandler;
        incentiveMechanism = _incentiveMechanism;
        classifier = _classifier;
    }

    function addData(
        int64[] memory data,
        uint64 classification
    ) public payable {
        uint cost = incentiveMechanism.handleAddData(
            msg.value,
            data,
            classification
        );
        uint time = dataHandler.handleAddData(
            msg.sender,
            cost,
            data,
            classification
        );

        classifier.update(data, classification);

        // Safe subtraction because cost <= msg.value.
        uint remaining = msg.value - cost;
        if (remaining > 0) {
            msg.sender.transfer(remaining);
        }
        // Emit here so that it's easier to catch.
        emit AddData(data, classification, time, msg.sender, cost);
    }

    function refund(
        int64[] memory data,
        uint64 classification,
        uint addedTime
    ) public {
        (
            uint claimableAmount,
            bool claimedBySubmitter,
            uint numClaims
        ) = dataHandler.handleRefund(
                msg.sender,
                data,
                classification,
                addedTime
            );
        uint64 prediction = classifier.predict(data);
        uint refundAmount = incentiveMechanism.handleRefund(
            msg.sender,
            data,
            classification,
            addedTime,
            claimableAmount,
            claimedBySubmitter,
            prediction,
            numClaims
        );
        msg.sender.transfer(refundAmount);
    }

    function report(
        int64[] memory data,
        uint64 classification,
        uint addedTime,
        address originalAuthor
    ) public {
        (
            uint initialDeposit,
            uint claimableAmount,
            bool claimedByReporter,
            uint numClaims,
            bytes32 dataKey
        ) = dataHandler.handleReport(
                msg.sender,
                data,
                classification,
                addedTime,
                originalAuthor
            );
        uint64 prediction = classifier.predict(data);
        uint rewardAmount = incentiveMechanism.handleReport(
            msg.sender,
            data,
            classification,
            addedTime,
            originalAuthor,
            initialDeposit,
            claimableAmount,
            claimedByReporter,
            prediction,
            numClaims
        );
        dataHandler.updateClaimableAmount(dataKey, rewardAmount);

        msg.sender.transfer(rewardAmount);
    }
}
