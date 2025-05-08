const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("FeedbackLinkSystem", function () {
  let FeedbackLinkSystem;
  let feedbackSystem;
  let owner, admin, user1, user2;

  before(async () => {
    [owner, admin, user1, user2] = await ethers.getSigners();
    FeedbackLinkSystem = await ethers.getContractFactory("FeedbackLinkSystem");
    feedbackSystem = await upgrades.deployProxy(FeedbackLinkSystem);
    await feedbackSystem.deployed();

    // Add an admin for testing
    await feedbackSystem.connect(owner).addAdmin(admin.address);
  });

  it("Should initialize with owner as admin", async () => {
    expect(await feedbackSystem.admins(owner.address)).to.equal(true);
  });
});

describe("Link Management", () => {
  let linkId;
  const topic = ethers.utils.formatBytes32String("Product Feedback");
  const description = ethers.utils.formatBytes32String("Share your thoughts");

  it("Should create a new feedback link", async () => {
    const tx = await feedbackSystem.connect(user1).createLink(
      ethers.utils.formatBytes32String("link1"),
      topic,
      description,
      false // isPrivate
    );
    const receipt = await tx.wait();
    const event = receipt.events.find(e => e.event === "LinkCreated");
    linkId = event.args.linkId;

    expect(await feedbackSystem.links(linkId)).to.exist;
  });

  it("Should fail to create a link with empty topic", async () => {
    await expect(
      feedbackSystem.connect(user1).createLink(
        ethers.utils.formatBytes32String("empty-topic"),
        "0x", // Empty topic
        description,
        false
      )
    ).to.be.revertedWith("Topic cannot be empty");
  });
});

describe("Feedback Submission", () => {
  let linkId;

  before(async () => {
    // Create a test link
    const tx = await feedbackSystem.connect(user1).createLink(
      ethers.utils.formatBytes32String("feedback-test"),
      ethers.utils.formatBytes32String("Test Topic"),
      ethers.utils.formatBytes32String("Test Description"),
      false
    );
    const receipt = await tx.wait();
    linkId = receipt.events[0].args.linkId;
  });

  it("Should submit feedback to a public link", async () => {
    const feedbackContent = ethers.utils.formatBytes32String("Great work!");
    await expect(
      feedbackSystem.connect(user2).submitFeedback(linkId, feedbackContent)
    ).to.emit(feedbackSystem, "FeedbackSubmitted");
  });

  it("Should reject empty feedback", async () => {
    await expect(
      feedbackSystem.connect(user2).submitFeedback(linkId, "0x")
    ).to.be.revertedWith("Feedback content cannot be empty");
  });
});

describe("Admin Functions", () => {
  it("Should allow admin to add/remove admins", async () => {
    // Add admin
    await feedbackSystem.connect(admin).addAdmin(user1.address);
    expect(await feedbackSystem.admins(user1.address)).to.equal(true);

    // Remove admin
    await feedbackSystem.connect(admin).removeAdmin(user1.address);
    expect(await feedbackSystem.admins(user1.address)).to.equal(false);
  });

  it("Should prevent non-admins from changing link privacy", async () => {
    const tx = await feedbackSystem.connect(user1).createLink(
      ethers.utils.formatBytes32String("admin-test"),
      ethers.utils.formatBytes32String("Admin Test"),
      ethers.utils.formatBytes32String("Test"),
      false
    );
    const linkId = (await tx.wait()).events[0].args.linkId;

    await expect(
      feedbackSystem.connect(user2).setLinkPrivacy(linkId, true)
    ).to.be.revertedWith("Only admin can perform this action");
  });
});

describe("Privacy Controls", () => {
  let privateLinkId;

  before(async () => {
    // Create a private link
    const tx = await feedbackSystem.connect(admin).createLink(
      ethers.utils.formatBytes32String("private-link"),
      ethers.utils.formatBytes32String("Secret Feedback"),
      ethers.utils.formatBytes32String("Confidential"),
      true // isPrivate
    );
    privateLinkId = (await tx.wait()).events[0].args.linkId;
  });

  it("Should allow admin to submit to private links", async () => {
    const feedback = ethers.utils.formatBytes32String("Admin feedback");
    await expect(
      feedbackSystem.connect(admin).submitFeedback(privateLinkId, feedback)
    ).to.emit(feedbackSystem, "FeedbackSubmitted");
  });

  it("Should reject non-admin submissions to private links", async () => {
    const feedback = ethers.utils.formatBytes32String("User feedback");
    await expect(
      feedbackSystem.connect(user1).submitFeedback(privateLinkId, feedback)
    ).to.be.revertedWith("Only admins can submit feedback to private links");
  });
});

describe("View Functions", () => {
  let testLinkId;

  before(async () => {
    // Create a test link with feedback
    const tx = await feedbackSystem.connect(user1).createLink(
      ethers.utils.formatBytes32String("view-test"),
      ethers.utils.formatBytes32String("View Test"),
      ethers.utils.formatBytes32String("Test"),
      false
    );
    testLinkId = (await tx.wait()).events[0].args.linkId;

    // Submit sample feedback
    await feedbackSystem.connect(user2).submitFeedback(
      testLinkId,
      ethers.utils.formatBytes32String("First feedback")
    );
  });

  it("Should return active public links", async () => {
    const links = await feedbackSystem.getActivePublicLinks();
    expect(links).to.include(testLinkId);
  });

  it("Should return feedback details", async () => {
    const [contents] = await feedbackSystem.getLinkFeedbacks(testLinkId);
    expect(contents[0]).to.equal(ethers.utils.formatBytes32String("First feedback"));
  });
});