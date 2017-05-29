import Poll from '~/lib/utils/poll';

const waitForAllCallsToFinish = (service, waitForCount, successCallback) => {
  const timer = () => {
    setTimeout(() => {
      if (service.fetch.calls.count() === waitForCount) {
        successCallback();
      } else {
        timer();
      }
    }, 0);
  };

  timer();
};

function mockServiceCall(service, response, shouldFail = false) {
  const action = shouldFail ? Promise.reject : Promise.resolve;
  const responseObject = response;

  if (!responseObject.headers) responseObject.headers = {};

  service.fetch.and.callFake(action.bind(Promise, responseObject));
}

describe('Poll', () => {
  const service = jasmine.createSpyObj('service', ['fetch']);
  const callbacks = jasmine.createSpyObj('callbacks', ['success', 'error']);

  afterEach(() => {
    callbacks.success.calls.reset();
    callbacks.error.calls.reset();
    service.fetch.calls.reset();
  });

  it('calls the success callback when no header for interval is provided', (done) => {
    mockServiceCall(service, { status: 200 });

    new Poll({
      resource: service,
      method: 'fetch',
      successCallback: callbacks.success,
      errorCallback: callbacks.error,
    }).makeRequest();

    waitForAllCallsToFinish(service, 1, () => {
      expect(callbacks.success).toHaveBeenCalled();
      expect(callbacks.error).not.toHaveBeenCalled();

      done();
    });
  });

  it('calls the error callback whe the http request returns an error', (done) => {
    mockServiceCall(service, { status: 500 }, true);

    new Poll({
      resource: service,
      method: 'fetch',
      successCallback: callbacks.success,
      errorCallback: callbacks.error,
    }).makeRequest();

    waitForAllCallsToFinish(service, 1, () => {
      expect(callbacks.success).not.toHaveBeenCalled();
      expect(callbacks.error).toHaveBeenCalled();

      done();
    });
  });

  it('should call the success callback when the interval header is -1', (done) => {
    mockServiceCall(service, { status: 200, headers: { 'poll-interval': -1 } });

    new Poll({
      resource: service,
      method: 'fetch',
      successCallback: callbacks.success,
      errorCallback: callbacks.error,
    }).makeRequest().then(() => {
      expect(callbacks.success).toHaveBeenCalled();
      expect(callbacks.error).not.toHaveBeenCalled();

      done();
    }).catch(done.fail);
  });

  it('starts polling when http status is 200 and interval header is provided', (done) => {
    mockServiceCall(service, { status: 200, headers: { 'poll-interval': 1 } });

    const Polling = new Poll({
      resource: service,
      method: 'fetch',
      data: { page: 1 },
      successCallback: callbacks.success,
      errorCallback: callbacks.error,
    });

    Polling.makeRequest();

    waitForAllCallsToFinish(service, 2, () => {
      Polling.stop();

      expect(service.fetch.calls.count()).toEqual(2);
      expect(service.fetch).toHaveBeenCalledWith({ page: 1 });
      expect(callbacks.success).toHaveBeenCalled();
      expect(callbacks.error).not.toHaveBeenCalled();

      done();
    });
  });

  describe('stop', () => {
    it('stops polling when method is called', (done) => {
      mockServiceCall(service, { status: 200, headers: { 'poll-interval': 1 } });

      const Polling = new Poll({
        resource: service,
        method: 'fetch',
        data: { page: 1 },
        successCallback: () => {
          Polling.stop();
        },
        errorCallback: callbacks.error,
      });

      spyOn(Polling, 'stop').and.callThrough();

      Polling.makeRequest();

      waitForAllCallsToFinish(service, 1, () => {
        expect(service.fetch.calls.count()).toEqual(1);
        expect(service.fetch).toHaveBeenCalledWith({ page: 1 });
        expect(Polling.stop).toHaveBeenCalled();

        done();
      });
    });
  });

  describe('restart', () => {
    it('should restart polling when its called', (done) => {
      mockServiceCall(service, { status: 200, headers: { 'poll-interval': 1 } });

      const Polling = new Poll({
        resource: service,
        method: 'fetch',
        data: { page: 1 },
        successCallback: () => {
          Polling.stop();
          setTimeout(() => {
            Polling.restart();
          }, 0);
        },
        errorCallback: callbacks.error,
      });

      spyOn(Polling, 'stop').and.callThrough();
      spyOn(Polling, 'restart').and.callThrough();

      Polling.makeRequest();

      waitForAllCallsToFinish(service, 2, () => {
        Polling.stop();

        expect(service.fetch.calls.count()).toEqual(2);
        expect(service.fetch).toHaveBeenCalledWith({ page: 1 });
        expect(Polling.stop).toHaveBeenCalled();
        expect(Polling.restart).toHaveBeenCalled();

        done();
      });
    });
  });
});
