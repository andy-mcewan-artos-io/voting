var Vote = artifacts.require("./AventusVote.sol");
var Storage = artifacts.require("./Storage.sol");

contract('AventusVote', function(accounts) {
  var av, s;

  before(function() {
    return Vote.deployed().then(function(av_) {
      av = av_;
      return Storage.deployed();
    }).then(function(s_) {
      return s = s_;
    });
  });

  it("should toggle Freeze", function() {
      var pre;

      return s.getBoolean(web3.sha3("VoteFreeze")).then(function(pre_) {
        pre = pre_;

        return av.toggleLockFreeze();
      }).then(function() {
        return s.getBoolean(web3.sha3("VoteFreeze"));
      }).then(function(post) {
        console.log(pre, post)
        
        return assert.equal(pre, !post, "Vote Freeze did not update freeze");
      });
  });

});
