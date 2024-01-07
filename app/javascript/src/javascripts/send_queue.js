/**
 * A sequential request queue with a minimum time between requests.
 * @prop {Number} time The minimum amount of time between requests, in milliseconds.
 * @prop {Function[]} queue The queued functions.
 * @prop {Boolean} running If the queue is currently running.
 * @prop {Boolean} active If the queue is currently active.
 */
class RequestQueue {
    /**
     * @param {Number} [time] The minimum amount of time between requests, in milliseconds.
     */
    constructor(time) {
        this.time = time || 1000;
        this.queue = [];
        this.running = false;
        this.active = true;
    }

    /**
     * Add a request to the queue.
     * @param {Function} cb 
     */
    add(cb) {
        this.queue.push(cb);
        this.run();
    }

    /** Run the queue. This should only be called internally. */
    async run() {
        if(this.running || !this.active) {
            return;
        }

        const func = this.queue.shift();
        if(func === undefined) {
            this.running = false;
            return;
        }

        this.running = true;
        const start = Date.now();
        await Promise.resolve(func())
            .catch(err => console.error("Error in request handler:", err));
        const end = Date.now();

        const diff = this.time - (end - start);
        if(diff > 0) {
            // ensure each request takes at least TIMEms
            await new Promise(resolve => setTimeout(resolve, diff));
        }
        this.running = false;

        this.run();
    }

    /** Start the queue. */
    start() {
        this.active = true;
        this.run();
    }

    /** Stop the queue. */
    stop() {
        this.active = false;
        this.running = false;
    }
}

export const SendQueue = new RequestQueue(700);
export default RequestQueue;
