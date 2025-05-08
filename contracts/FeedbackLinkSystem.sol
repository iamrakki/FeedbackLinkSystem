// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title FeedbackLinkSystem
 * @dev A contract for managing feedback through unique links with privacy controls
 */
contract FeedbackLinkSystem is OwnableUpgradeable, UUPSUpgradeable {
    // Struct to store feedback information
    struct Feedback {
        address author;
        bytes content;
        uint256 timestamp;
    }

    // Struct to store link information
    struct Link {
        bytes32 linkId;
        address creator;
        bytes topic; // Add topic field
        bytes topicDescription; // Add topic description field
        bool isActive;
        bool isDeleted;
        bool isPrivate;
        uint256[] feedbackIds;
    }

    // Mapping from link ID to Link struct
    mapping(bytes32 => Link) public links;

    // Array to store all link IDs
    bytes32[] public allLinks;

    // Mapping from feedback ID to Feedback struct
    mapping(uint256 => Feedback) public feedbacks;

    // Counter for feedback IDs
    uint256 public feedbackCount;

    // Admin addresses with special privileges
    mapping(address => bool) public admins;

    // Events
    event LinkCreated(
        bytes32 indexed linkId,
        address indexed creator,
        bool isPrivate
    );
    event LinkStatusChanged(bytes32 indexed linkId, bool isActive);
    event LinkPrivacyChanged(bytes32 indexed linkId, bool isPrivate);
    event LinkDeleted(bytes32 indexed linkId);
    event FeedbackSubmitted(
        uint256 feedbackId,
        bytes32 indexed linkId,
        address indexed author,
        uint256 timestamp,
        bool isActive,
        bool isPrivate
    );
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);

    // Modifier to restrict function access to admins only
    modifier onlyAdmin() {
        require(admins[msg.sender], "Only admin can perform this action");
        _;
    }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        admins[msg.sender] = true;
        emit AdminAdded(msg.sender);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    receive() external payable {}

    /**
     * @dev Add a new admin
     * @param _admin Address of the new admin
     */
    function addAdmin(address _admin) external onlyAdmin {
        require(_admin != address(0), "Invalid address");
        require(!admins[_admin], "Address is already an admin");

        admins[_admin] = true;
        emit AdminAdded(_admin);
    }

    /**
     * @dev Remove an admin
     * @param _admin Address of the admin to remove
     */
    function removeAdmin(address _admin) external onlyAdmin {
        require(_admin != address(0), "Invalid address");
        require(admins[_admin], "Address is not an admin");
        require(_admin != msg.sender, "Cannot remove yourself as admin");

        admins[_admin] = false;
        emit AdminRemoved(_admin);
    }

    /**
     * @dev Create a new feedback link with topic and description
     * @param _linkName Name/identifier for the link (will be hashed)
     * @param _topic Topic of the feedback link (in bytes)
     * @param _topicDescription Description of the feedback link (in bytes)
     * @param _isPrivate Whether the link is private (only accessible by admins)
     * @return linkId Unique ID for the created link
     */
    function createLink(
        bytes calldata _linkName,
        bytes calldata _topic,
        bytes calldata _topicDescription,
        bool _isPrivate
    ) external returns (bytes32) {
        require(_topic.length > 0, "Topic cannot be empty");

        bytes32 linkId = keccak256(
            abi.encodePacked(_linkName, msg.sender, block.timestamp)
        );

        require(links[linkId].linkId == bytes32(0), "Link already exists");

        links[linkId] = Link({
            linkId: linkId,
            creator: msg.sender,
            topic: _topic,
            topicDescription: _topicDescription,
            isActive: true,
            isDeleted: false,
            isPrivate: _isPrivate,
            feedbackIds: new uint256[](0)
        });

        allLinks.push(linkId);
        emit LinkCreated(linkId, msg.sender, _isPrivate);

        return linkId;
    }

    /**
     * @dev Change the active status of a link
     * @param _linkId ID of the link
     * @param _isActive New active status
     */
    function setLinkStatus(bytes32 _linkId, bool _isActive) external onlyAdmin {
        require(links[_linkId].linkId != bytes32(0), "Link does not exist");
        require(!links[_linkId].isDeleted, "Link has been deleted");

        links[_linkId].isActive = _isActive;
        emit LinkStatusChanged(_linkId, _isActive);
    }

    /**
     * @dev Change the privacy status of a link
     * @param _linkId ID of the link
     * @param _isPrivate New privacy status
     */
    function setLinkPrivacy(bytes32 _linkId, bool _isPrivate)
        external
        onlyAdmin
    {
        require(links[_linkId].linkId != bytes32(0), "Link does not exist");
        require(!links[_linkId].isDeleted, "Link has been deleted");

        links[_linkId].isPrivate = _isPrivate;
        emit LinkPrivacyChanged(_linkId, _isPrivate);
    }

    /**
     * @dev Delete a link
     * @param _linkId ID of the link to delete
     */
    function deleteLink(bytes32 _linkId) external onlyAdmin {
        require(links[_linkId].linkId != bytes32(0), "Link does not exist");
        require(!links[_linkId].isDeleted, "Link has already been deleted");

        links[_linkId].isDeleted = true;
        links[_linkId].isActive = false;

        emit LinkDeleted(_linkId);
    }

    /**
     * @dev Submit feedback through a specific link
     * @param _linkId ID of the link to submit feedback to
     * @param _content Content of the feedback as bytes
     * @return feedbackId ID of the created feedback
     */
    function submitFeedback(bytes32 _linkId, bytes calldata _content)
        external
        returns (uint256)
    {
        require(links[_linkId].linkId != bytes32(0), "Link does not exist");
        require(!links[_linkId].isDeleted, "Link has been deleted");
        require(links[_linkId].isActive, "Link is not active");
        require(_content.length > 0, "Feedback content cannot be empty");

        if (links[_linkId].isPrivate) {
            require(
                admins[msg.sender],
                "Only admins can submit feedback to private links"
            );
        }

        uint256 feedbackId = feedbackCount;

        feedbacks[feedbackId] = Feedback({
            author: msg.sender,
            content: _content,
            timestamp: block.timestamp
        });

        links[_linkId].feedbackIds.push(feedbackId);

        emit FeedbackSubmitted(
            feedbackId,
            _linkId,
            msg.sender,
            block.timestamp,
            links[_linkId].isActive,
            links[_linkId].isPrivate
        );

        feedbackCount++;
        return feedbackId;
    }

    /**
     * @dev Get feedback IDs for a specific link
     * @param _linkId ID of the link
     * @return Array of feedback IDs for the link that the caller can access
     */
    function getLinkFeedbackIds(bytes32 _linkId)
        external
        view
        returns (uint256[] memory)
    {
        require(links[_linkId].linkId != bytes32(0), "Link does not exist");

        // If link is deleted or inactive, return empty array
        if (links[_linkId].isDeleted || !links[_linkId].isActive) {
            return new uint256[](0);
        }

        // For private links, only admins can view feedback
        if (links[_linkId].isPrivate && !admins[msg.sender]) {
            return new uint256[](0);
        }

        return links[_linkId].feedbackIds;
    }

    // /**
    //  * @dev Get feedback content
    //  * @param _feedbackId ID of the feedback
    //  * @return content, timestamp, author
    //  */
    function getFeedback(uint256 _feedbackId)
        external
        view
        returns (
            bytes memory content,
            uint256 timestamp,
            address author
        )
    {
        require(_feedbackId < feedbackCount, "Feedback does not exist");
        Feedback storage feedback = feedbacks[_feedbackId];

        // Find which link this feedback belongs to
        bytes32 feedbackLinkId;
        bool isFound = false;

        for (uint256 i = 0; i < allLinks.length && !isFound; i++) {
            bytes32 linkId = allLinks[i];
            uint256[] memory linkFeedbacks = links[linkId].feedbackIds;

            for (uint256 j = 0; j < linkFeedbacks.length; j++) {
                if (linkFeedbacks[j] == _feedbackId) {
                    feedbackLinkId = linkId;
                    isFound = true;
                    break;
                }
            }
        }

        // If the feedback is from a private link and caller is not admin, restrict access
        if (isFound && links[feedbackLinkId].isPrivate && !admins[msg.sender]) {
            return (
                bytes("Private feedback - only visible to admins"),
                feedback.timestamp,
                feedback.author
            );
        }

        return (feedback.content, feedback.timestamp, feedback.author);
    }

    /**
     * @dev Check if a link is active and not deleted
     * @param _linkId ID of the link
     * @return status True if link is active and not deleted
     */
    function isLinkActive(bytes32 _linkId) external view returns (bool) {
        return (links[_linkId].linkId != bytes32(0) &&
            links[_linkId].isActive &&
            !links[_linkId].isDeleted);
    }

    /**
     * @dev Check if a link is private
     * @param _linkId ID of the link
     * @return status True if link is private (admin-only)
     */
    function isLinkPrivate(bytes32 _linkId) external view returns (bool) {
        require(links[_linkId].linkId != bytes32(0), "Link does not exist");
        return links[_linkId].isPrivate;
    }

    /**
     * @dev Get topic and description for a link
     * @param _linkId ID of the link
     * @return topic Topic of the link
     * @return topicDescription Description of the link
     */
    function getLinkTopic(bytes32 _linkId)
        external
        view
        returns (bytes memory topic, bytes memory topicDescription)
    {
        require(links[_linkId].linkId != bytes32(0), "Link does not exist");
        require(!links[_linkId].isDeleted, "Link has been deleted");

        return (links[_linkId].topic, links[_linkId].topicDescription);
    }

    /**
     * @dev Get full link information including topic and description
     * @param _linkId ID of the link
     * @return creator Address of link creator
     * @return topic Topic of the link
     * @return topicDescription Description of the link
     * @return isActive Whether the link is active
     * @return isPrivate Whether the link is private
     * @return isDeleted Whether the link is deleted
     * @return feedbackCount Number of feedbacks in the link
     */
    function getFullLinkInfo(bytes32 _linkId)
        external
        view
        returns (
            address creator,
            bytes memory topic,
            bytes memory topicDescription,
            bool isActive,
            bool isPrivate,
            bool isDeleted,
            uint256 feedbackCount
        )
    {
        require(links[_linkId].linkId != bytes32(0), "Link does not exist");
        Link storage link = links[_linkId];

        return (
            link.creator,
            link.topic,
            link.topicDescription,
            link.isActive,
            link.isPrivate,
            link.isDeleted,
            link.feedbackIds.length
        );
    }

    /**
     * @dev Get all active public links
     * @return Array of active public link IDs
     */
    function getActivePublicLinks() external view returns (bytes32[] memory) {
        uint256 activeCount = 0;

        // First count active public links
        for (uint256 i = 0; i < allLinks.length; i++) {
            bytes32 linkId = allLinks[i];
            if (
                links[linkId].isActive &&
                !links[linkId].isDeleted &&
                !links[linkId].isPrivate
            ) {
                activeCount++;
            }
        }

        // Then create result array with active public links
        bytes32[] memory result = new bytes32[](activeCount);
        uint256 resultIndex = 0;

        for (uint256 i = 0; i < allLinks.length; i++) {
            bytes32 linkId = allLinks[i];
            if (
                links[linkId].isActive &&
                !links[linkId].isDeleted &&
                !links[linkId].isPrivate
            ) {
                result[resultIndex] = linkId;
                resultIndex++;
            }
        }

        return result;
    }

    /**
     * @dev Get all active links (both public and private)
     * @return Array of all active link IDs
     */
    function getAllActiveLinks()
        external
        view
        onlyAdmin
        returns (bytes32[] memory)
    {
        uint256 activeCount = 0;

        // First count active links
        for (uint256 i = 0; i < allLinks.length; i++) {
            bytes32 linkId = allLinks[i];
            if (links[linkId].isActive && !links[linkId].isDeleted) {
                activeCount++;
            }
        }

        // Then create result array with active links
        bytes32[] memory result = new bytes32[](activeCount);
        uint256 resultIndex = 0;

        for (uint256 i = 0; i < allLinks.length; i++) {
            bytes32 linkId = allLinks[i];
            if (links[linkId].isActive && !links[linkId].isDeleted) {
                result[resultIndex] = linkId;
                resultIndex++;
            }
        }

        return result;
    }

    /**
     * @dev Get all link IDs created by a specific address
     * @param creator Address of the link creator
     * @return Array of link IDs created by the specified address
     */
    /**
     * @dev Get all links created by a specific address with full details
     * @param creator Address of the link creator
     * @return linkIds Array of link IDs
     * @return topics Array of topics
     * @return topicDescriptions Array of topic descriptions
     * @return isActiveArray Array of active statuses
     * @return isPrivateArray Array of privacy statuses
     * @return isDeletedArray Array of Delete statuses
     * @return feedbackCounts Array of feedback counts
     */
    function getLinksByCreator(address creator)
        external
        view
        returns (
            bytes32[] memory linkIds,
            bytes[] memory topics,
            bytes[] memory topicDescriptions,
            bool[] memory isActiveArray,
            bool[] memory isPrivateArray,
            bool[] memory isDeletedArray,
            uint256[] memory feedbackCounts
        )
    {
        // First count how many links this creator has
        uint256 count = 0;
        for (uint256 i = 0; i < allLinks.length; i++) {
            if (links[allLinks[i]].creator == creator) {
                count++;
            }
        }

        // Initialize arrays with the correct size
        linkIds = new bytes32[](count);
        topics = new bytes[](count);
        topicDescriptions = new bytes[](count);
        isActiveArray = new bool[](count);
        isPrivateArray = new bool[](count);
        isDeletedArray = new bool[](count);
        feedbackCounts = new uint256[](count);

        // Populate the arrays
        uint256 index = 0;
        for (uint256 i = 0; i < allLinks.length; i++) {
            bytes32 linkId = allLinks[i];
            Link storage link = links[linkId];

            if (link.creator == creator) {
                linkIds[index] = linkId;
                topics[index] = link.topic;
                topicDescriptions[index] = link.topicDescription;
                isActiveArray[index] = link.isActive;
                isPrivateArray[index] = link.isPrivate;
                isDeletedArray[index] = link.isDeleted;
                feedbackCounts[index] = link.feedbackIds.length;
                index++;
            }
        }

        return (
            linkIds,
            topics,
            topicDescriptions,
            isActiveArray,
            isPrivateArray,
            isDeletedArray,
            feedbackCounts
        );
    }

    /**
     * @dev Get all feedback details submitted by a specific address to a specific link
     * @param _linkId ID of the link
     * @param submitter Address of the user who submitted feedback
     * @return contents Array of feedback content (bytes)
     * @return timestamps Array of submission timestamps
     * @return feedbackIds Array of feedback IDs
     */
    function getFeedbackDetailsBySubmitter(bytes32 _linkId, address submitter)
        external
        view
        returns (
            bytes[] memory contents,
            uint256[] memory timestamps,
            uint256[] memory feedbackIds
        )
    {
        require(links[_linkId].linkId != bytes32(0), "Link does not exist");

        // If link is deleted, return empty arrays
        if (links[_linkId].isDeleted) {
            return (new bytes[](0), new uint256[](0), new uint256[](0));
        }

        // For private links, only admins or the submitter can view feedback
        if (
            links[_linkId].isPrivate &&
            !admins[msg.sender] &&
            msg.sender != submitter
        ) {
            return (new bytes[](0), new uint256[](0), new uint256[](0));
        }

        // Count how many feedbacks this submitter has in this link
        uint256 count = 0;
        uint256[] memory allFeedbackIds = links[_linkId].feedbackIds;

        for (uint256 i = 0; i < allFeedbackIds.length; i++) {
            if (feedbacks[allFeedbackIds[i]].author == submitter) {
                count++;
            }
        }

        // Create and populate the result arrays
        contents = new bytes[](count);
        timestamps = new uint256[](count);
        feedbackIds = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < allFeedbackIds.length; i++) {
            if (feedbacks[allFeedbackIds[i]].author == submitter) {
                contents[index] = feedbacks[allFeedbackIds[i]].content;
                timestamps[index] = feedbacks[allFeedbackIds[i]].timestamp;
                feedbackIds[index] = allFeedbackIds[i];
                index++;
            }
        }

        return (contents, timestamps, feedbackIds);
    }

    /**
     * @dev Get all feedback submissions for a specific link
     * @param _linkId ID of the link
     * @return contents Array of feedback content
     * @return authors Array of feedback authors
     * @return timestamps Array of submission timestamps
     * @return feedbackIds Array of feedback IDs
     */
    function getLinkFeedbacks(bytes32 _linkId)
        external
        view
        returns (
            bytes[] memory contents,
            address[] memory authors,
            uint256[] memory timestamps,
            uint256[] memory feedbackIds
        )
    {
        require(links[_linkId].linkId != bytes32(0), "Link does not exist");
        require(!links[_linkId].isDeleted, "Link has been deleted");

        uint256[] memory linkFeedbackIds = links[_linkId].feedbackIds;
        uint256 feedbackCount = linkFeedbackIds.length;

        contents = new bytes[](feedbackCount);
        authors = new address[](feedbackCount);
        timestamps = new uint256[](feedbackCount);
        feedbackIds = new uint256[](feedbackCount);

        for (uint256 i = 0; i < feedbackCount; i++) {
            uint256 feedbackId = linkFeedbackIds[i];
            Feedback storage feedback = feedbacks[feedbackId];

            contents[i] = feedback.content;
            authors[i] = feedback.author;
            timestamps[i] = feedback.timestamp;
            feedbackIds[i] = feedbackId;
        }

        return (contents, authors, timestamps, feedbackIds);
    }
}
