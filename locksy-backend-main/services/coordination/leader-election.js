/*
 * Leader Election
 * Distributed leader election using Zookeeper
 */

const zookeeperClient = require('./zookeeper-client');

class LeaderElection {
  constructor() {
    this.electionPath = '/locksy/elections';
    this.currentElection = null;
    this.isLeader = false;
    this.leaderPath = null;
  }

  /**
   * Participate in leader election
   * @param {string} electionName - Election name
   * @param {Function} onBecomeLeader - Callback when becoming leader
   * @param {Function} onLoseLeadership - Callback when losing leadership
   * @returns {Promise<string>} Election path
   */
  async participate(electionName, onBecomeLeader = null, onLoseLeadership = null) {
    try {
      await zookeeperClient.connect();
      
      const electionPath = `${this.electionPath}/${electionName}`;
      await zookeeperClient.ensurePath(electionPath);

      // Create ephemeral sequential node
      const candidatePath = `${electionPath}/candidate-`;
      const createdPath = await zookeeperClient.createNode(
        candidatePath,
        {
          pid: process.pid,
          hostname: require('os').hostname(),
          timestamp: new Date().toISOString()
        },
        zookeeperClient.client.CreateMode.EPHEMERAL_SEQUENTIAL
      );

      this.currentElection = electionName;
      this.leaderPath = createdPath;

      // Check if we're the leader
      await this.checkLeadership(electionPath, createdPath, onBecomeLeader, onLoseLeadership);

      // Watch for leader changes
      this.watchLeader(electionPath, createdPath, onBecomeLeader, onLoseLeadership);

      console.log(`LeaderElection: Participating in election ${electionName} with path ${createdPath}`);
      return createdPath;
    } catch (error) {
      console.error('LeaderElection: Error participating in election:', error.message);
      throw error;
    }
  }

  /**
   * Check if we're the leader
   * @param {string} electionPath - Election path
   * @param {string} ourPath - Our candidate path
   * @param {Function} onBecomeLeader - Callback
   * @param {Function} onLoseLeadership - Callback
   */
  async checkLeadership(electionPath, ourPath, onBecomeLeader, onLoseLeadership) {
    try {
      const children = await zookeeperClient.listChildren(electionPath);
      if (children.length === 0) {
        return;
      }

      // Sort children to get sequential order
      children.sort();

      // Extract our sequence number
      const ourSeq = this.extractSequence(ourPath);
      
      // Find our position
      const ourIndex = children.findIndex(child => {
        const childPath = `${electionPath}/${child}`;
        return this.extractSequence(childPath) === ourSeq;
      });

      // Check if we're first (leader)
      const wasLeader = this.isLeader;
      this.isLeader = ourIndex === 0;

      if (this.isLeader && !wasLeader) {
        console.log(`LeaderElection: Became leader for ${this.currentElection}`);
        if (onBecomeLeader) {
          onBecomeLeader();
        }
      } else if (!this.isLeader && wasLeader) {
        console.log(`LeaderElection: Lost leadership for ${this.currentElection}`);
        if (onLoseLeadership) {
          onLoseLeadership();
        }
      }
    } catch (error) {
      console.error('LeaderElection: Error checking leadership:', error.message);
    }
  }

  /**
   * Watch for leader changes
   * @param {string} electionPath - Election path
   * @param {string} ourPath - Our candidate path
   * @param {Function} onBecomeLeader - Callback
   * @param {Function} onLoseLeadership - Callback
   */
  watchLeader(electionPath, ourPath, onBecomeLeader, onLoseLeadership) {
    const watch = () => {
      zookeeperClient.client.getChildren(
        electionPath,
        (event) => {
          // Children changed, check leadership again
          this.checkLeadership(electionPath, ourPath, onBecomeLeader, onLoseLeadership);
          watch(); // Re-watch
        },
        (error, children) => {
          if (error) {
            console.error('LeaderElection: Watch error:', error.message);
            return;
          }
          
          // Initial check
          this.checkLeadership(electionPath, ourPath, onBecomeLeader, onLoseLeadership);
        }
      );
    };

    watch();
  }

  /**
   * Extract sequence number from path
   * @param {string} path - Zookeeper path
   * @returns {number} Sequence number
   */
  extractSequence(path) {
    const match = path.match(/candidate-(\d+)$/);
    return match ? parseInt(match[1]) : Infinity;
  }

  /**
   * Check if we're the leader
   * @returns {boolean} True if leader
   */
  isCurrentLeader() {
    return this.isLeader;
  }

  /**
   * Withdraw from election
   */
  async withdraw() {
    try {
      if (this.leaderPath) {
        await zookeeperClient.deleteNode(this.leaderPath);
        this.leaderPath = null;
        this.isLeader = false;
        this.currentElection = null;
        console.log('LeaderElection: Withdrawn from election');
      }
    } catch (error) {
      console.error('LeaderElection: Error withdrawing:', error.message);
    }
  }
}

// Export singleton instance
const leaderElection = new LeaderElection();
module.exports = leaderElection;


