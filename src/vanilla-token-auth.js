import Cookies from 'js-cookie';
import cloneDeep from 'lodash/fp/cloneDeep';
import isObject from 'lodash/fp/isObject';

/**
 * @typedef CustomOptions
 * @property {Object} [params] params
 * @property {string} [config] config name
 * @property {string} [auth_origin_url] the auth origin url
 */

/**
 * @typedef RejectOptions
 * @property {string} reason reason
 * @property {string[]} errors errors
 */

/**
 * @typedef AuthHeaders
 * @property {string} `access-token` access-token
 * @property {string} `token-type` token-type
 * @property {string} client client
 * @property {string} expiry expiry
 * @property {string} uid uid
 */

/**
 * @typedef ConfigAuthProviderPaths
 * @property {string} google_oauth2 Google OAuth2
 * @property {string} facebook Facebook
 * @property {string} apple_quantic Apple quantic
 * @property {string} apple_smartly Apple smartly
 * @property {string} twitter Twitter
 * @property {string} onelogin OneLogin
 * @property {string} wechat WeChat
 */

/**
 * @typedef CustomStorage
 * @property {(key: string, val: string) => void} persistData persist data
 * @property {(key: string) => void} retrieveData retrieve data
 * @property {(key: string) => void} deleteData delete data
 */

/**
 * @typedef Config
 * @property {string} apiUrl The base route to your api. Each of the following paths will be relative to this URL. Authentication headers will only be added to requests with this value as the base URL.
 * @property {string} signOutUrl Relative path to sign user out. this will destroy the user's token both server-side and client-side.
 * @property {string} emailSignInPath Path for signing in using email credentials.
 * @property {string} emailRegistrationPath Path for submitting new email registrations.
 * @property {string} accountUpdatePath Path for submitting account update requests.
 * @property {string} accountDeletePath Path for submitting account deletion requests.
 * @property {string|() => string} confirmationSuccessUrl The url to which the API should redirect after users visit the link contained in email-registration emails.
 * @property {string} passwordResetPath Path for requesting password reset emails.
 * @property {string} passwordUpdatePath Path for submitting new passwords for authenticated users.
 * @property {string|() => string} passwordResetSuccessUrl The URL to which the API should redirect after users visit the links contained in password-reset emails.
 * @property {string} tokenValidationPath Relative path to validate authentication tokens.
 * @property {() => boolean} proxyIf Older browsers have trouble with CORS. Pass a method here to determine whether or not a proxy should be used. Example: `function() { return !Modernizr.cors }`.
 * @property {string} proxyUrl Proxy url if proxy is to be used
 * @property {boolean} validateOnPageLoad Check if a user's auth token exists and is valid on page load.
 * @property {string} omniauthWindowType Dictates the methodology of the OAuth login flow. One of: `sameWindow` (default), `newWindow`, or `inAppBrowser`.
 * @property {string|CustomStorage} storage The method used to persist tokens between sessions. cookies are used by default, but `window.localStorage` and `window.sessionStorage` can be used as well. A custom object can also be used. Allowed strings are `cookies`, `localStorage`, and `sessionStorage`, otherwise an object implementing the following interface: `{ function persistData(key, val) {}, function retrieveData(key) {}, function deleteData(key) {} }`.
 * @property {string} transport The transport used to send the auth token to the server. Either `cookies` (default) or `headers`.
 * @property {boolean} forceValidateToken If this flag is set, the API's token validation will be called even if the auth token is not saved in `storage`. This can be useful for implementing a single sign-on (SSO) system.
 * @property {AuthHeaders} tokenFormat A template for authentication tokens. The template will be provided with a context containing `token`, `clientId`, `expiry`, and `uid` params.
 * @property {Cookies.CookieAttributes} cookieOps Cookie options for js-cookie
 * @property {(url: string) => Window|null} createPopup A function that will open OmniAuth window by `url`.
 * @property {(headers: object) => number|null} parseExpiry A function that will return the token's expiry from the current headers. Returns `null` if no headers or expiry are found.
 * @property {(resp: HttpResponse) => any} handleLoginResponse A function that will identify and return the current user's info (id, username, etc) in the response of a successful login request.
 * @property {(resp: HttpResponse) => any} handleAccountUpdateResponse A function that will identify and return the current user's info (id, username, etc) in the response of a successful account update request.
 * @property {(resp: HttpResponse) => any} handleTokenValidationResponse A function that will identify and return the current user's info (id, username, etc) in the response of a successful token validation request.
 * @property {ConfigAuthProviderPaths} authProviderPaths An object containing paths to auth endpoints. keys are names of the providers, values are their auth paths relative to the `apiUrl`.
 * @property {typeof fetch} httpWrapper A [`Fetch API`](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API) compatible function wrapper.
 * @property {(name: string, payload?: any) => void} broadcast Callback to be used by AngularJS to broadcast events.
 * @property {(url: string, replace?: boolean) => void} navigate Helper to navigate to pages programmatically.
 */

/**
 * @typedef HttpResponse
 * @property {any} data The response body transformed with the transform functions
 * @property {number} status HTTP status code of the response.
 */

/**
 * Interpolate a string with the given data.
 * Simple version of https://code.angularjs.org/1.7.9/docs/api/ng/service/$interpolate
 * @param {string} str string to interpolate
 * @param {Object} ctx context with variables for interpolation
 * @returns {string}
 */
function interpolate(str, ctx) {
    return str.replace(/{{\s?([a-zA-Z]+)\s?}}/g, (match, key) => ctx[key] || match);
}

/**
 * @type {Record<string, Config>}
 */
const configs = {
    default: {
        apiUrl: '/api',
        signOutUrl: '/auth/sign_out',
        emailSignInPath: '/auth/sign_in',
        emailRegistrationPath: '/auth',
        accountUpdatePath: '/auth',
        accountDeletePath: '/auth',
        confirmationSuccessUrl() {
            return window.location.href;
        },
        passwordResetPath: '/auth/password',
        passwordUpdatePath: '/auth/password',
        passwordResetSuccessUrl() {
            return window.location.href;
        },
        tokenValidationPath: '/auth/validate_token',
        // eslint-disable-next-line lodash-fp/prefer-constant
        proxyIf() {
            return false;
        },
        proxyUrl: '/proxy',
        validateOnPageLoad: true,
        omniauthWindowType: 'sameWindow',
        storage: 'cookies',
        transport: 'cookies',
        forceValidateToken: false,

        tokenFormat: {
            'access-token': '{{ token }}',
            'token-type': 'Bearer',
            client: '{{ clientId }}',
            expiry: '{{ expiry }}',
            uid: '{{ uid }}',
        },

        cookieOps: {
            path: '/',
            expires: 9999,
            secure: false,
        },

        // popups are difficult to test. mock this method in testing.
        createPopup(url) {
            return window.open(url, '_blank', 'closebuttoncaption=Cancel');
        },

        parseExpiry(headers) {
            // convert from ruby time (seconds) to js time (milliseconds)
            return parseInt(headers.expiry, 10) * 1000 || null;
        },

        handleLoginResponse(resp) {
            return resp.data;
        },
        handleAccountUpdateResponse(resp) {
            return resp.data;
        },
        handleTokenValidationResponse(resp) {
            return resp.data;
        },

        authProviderPaths: {
            google_oauth2: '/auth/google_oauth2',
            facebook: '/auth/facebook',
            apple_quantic: '/auth/apple_quantic',
            apple_smartly: '/auth/apple_smartly',
            twitter: '/auth/twitter',
            onelogin: '/auth/onelogin',
            wechat: '/auth/wechat',
            wechat_official_account: '/auth/wechat_official_account',
        },

        httpWrapper: fetch,

        broadcast(name, payload) {
            if (process.env.NODE_ENV === 'development') {
                console.log(`[${name}]:`, payload); // eslint-disable-line no-console
            }
        },

        navigate(url, replace) {
            if (replace) {
                return window.location.replace(url);
            }
            return window.location.assign(url);
        },
    },
};

let defaultConfigName = 'default';

export default class DeviseTokenAuthClient {
    /**
     * Configure DeviseTokenAuthClient with the given options.
     * @param {Partial<Config>|Array<Record<string, Partial<Config>>>} params options
     */
    constructor(params) {
        // user is using multiple concurrent configs (>1 user types).
        if (params instanceof Array && params.length) {
            // extend each item in array from default settings
            for (let i = 0; i < params.length; i++) {
                // get the name of the config
                const conf = params[i];
                let label = null;
                // eslint-disable-next-line no-restricted-syntax,guard-for-in
                for (const k in conf) {
                    label = k;

                    // set the first item in array as default config
                    if (i === 0) {
                        defaultConfigName = label;
                    }
                }

                // use copy preserve the original default settings object while
                // extending each config object
                const defaults = cloneDeep(configs.default);
                const fullConfig = {};
                fullConfig[label] = Object.assign(defaults, conf[label]);
                Object.assign(configs, fullConfig);
            }

            // remove existing default config
            if (defaultConfigName !== 'default') {
                delete configs.default;
            }
        } else if (params instanceof Object) {
            // user is extending the single default config
            Object.assign(configs.default, params);
        } else {
            // user is doing something wrong
            throw new Error('Invalid argument: DeviceTokenAuthClient config should be an Array or Object.');
        }
    }

    /**
     * Deferred object
     * @type {{ resolve: Function, reject: Function, promise: Promise }|null}
     */
    dfd = null;

    /**
     * User data object
     * @type {Object}
     */
    user = {};

    /**
     * Auth headers object
     * @type {Partial<AuthHeaders>}
     */
    headers = {};

    mustResetPassword = false;
    firstTimeLogin = false;
    oauthRegistration = false;

    /**
     * Window message listener
     * @type {Function|null}
     */
    listener = null;

    /**
     * Timer for auth window message listener
     * @type {number|null}
     */
    requestCredentialsPollingTimer = null;

    /**
     * Cleanup auth window message listeners
     * @type {Function|null}
     */
    cancelOmniauthInAppBrowserListeners = null;

    /**
     * Wrapper for fetch.
     * @param {RequestInfo} input
     * @param {RequestInit} [init]
     * @returns {Promise<HttpResponse>}
     */
    http(input, init) {
        const httpWrapper = this.getConfig().httpWrapper;
        return httpWrapper(input, init).then(res =>
            res.json().then(data => {
                const response = { data, status: res.status };
                return res.ok ? response : Promise.reject(response);
            }),
        );
    }

    /**
     * Called once at startup
     */
    initialize() {
        this.initializeListeners();
        this.cancelOmniauthInAppBrowserListeners = () => {};
        const currHeaders = this.retrieveData('auth_headers') || {};
        Object.assign(this.headers, currHeaders);

        // Check to see if user is returning user
        if (this.getConfig().validateOnPageLoad) {
            this.validateUser({ config: this.getSavedConfig() });
        }
    }

    /**
     * Setup listener for Window messages
     */
    initializeListeners() {
        this.listener = this.handlePostMessage.bind(this);

        if (window.addEventListener) {
            window.addEventListener('message', this.listener, false);
        }
    }

    /**
     * Cancel any existing timers, listeners, and promises
     * @param {RejectOptions} [reason] Reason for cancelling
     */
    cancel(reason) {
        // cancel any pending timers
        if (this.requestCredentialsPollingTimer != null) {
            window.clearTimeout(this.requestCredentialsPollingTimer);
        }

        // cancel inAppBrowser listeners if set
        if (this.cancelOmniauthInAppBrowserListeners) {
            this.cancelOmniauthInAppBrowserListeners();
        }

        // reject any pending promises
        if (this.dfd != null) {
            this.rejectDfd(reason);
        }

        // nullify timer after reflow
        window.setTimeout(() => {
            this.requestCredentialsPollingTimer = null;
        });
    }

    /**
     * Cancel any pending processes, clean up garbage
     */
    destroy() {
        this.cancel();

        if (window.removeEventListener) {
            window.removeEventListener('message', this.listener, false);
        }
    }

    /**
     * Handle the broadcast events from external auth tabs/popups
     * @param {MessageEvent<any>} ev Broadcast event
     */
    handlePostMessage(ev) {
        const config = this.getConfig();
        if (ev.data.message === 'deliverCredentials') {
            delete ev.data.message;

            // check if a new user was registered
            const oauthRegistration = ev.data.oauth_registration;
            this.handleValidAuth(ev.data, true);
            config.broadcast('auth:login-success', ev.data);
            if (oauthRegistration) {
                config.broadcast('auth:oauth-registration', ev.data);
            }
        }
        if (ev.data.message === 'authFailure') {
            const error = {
                reason: 'unauthorized',
                errors: [ev.data.error],
            };
            this.cancel(error);
            config.broadcast('auth:login-error', error);
        }
    }

    /**
     * Register by email. Server will send confirmation email containing
     * a link to activate the account. The link will redirect to this site.
     * @param {*} params registration parameters
     * @param {CustomOptions} opts options
     * @returns {Promise<HttpResponse>}
     */
    submitRegistration(params, opts = {}) {
        const config = this.getConfig(opts.config);
        return this.http(this.apiUrl(opts.config) + config.emailRegistrationPath, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                ...params,
                confirm_success_url: this.getResultOrValue(config.confirmationSuccessUrl),
                config_name: this.getCurrentConfigName(opts.config),
            }),
        }).then(
            resp => {
                config.broadcast('auth:registration-email-success', params);
                return resp;
            },
            resp => {
                config.broadcast('auth:registration-email-error', resp.data);
                return Promise.reject(resp);
            },
        );
    }

    /**
     * Capture input from user, authenticate server-side
     * @param {*} params login parameters
     * @param {CustomOptions} opts options
     * @returns {Promise<HttpResponse>}
     */
    submitLogin(params, opts = {}) {
        this.initDfd();
        const config = this.getConfig(opts.config);
        this.http(this.apiUrl(opts.config) + config.emailSignInPath, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(params),
        }).then(
            resp => {
                this.setConfigName(opts.config);
                const authData = config.handleLoginResponse(resp.data);
                this.handleValidAuth(authData);
                config.broadcast('auth:login-success', this.user);
            },
            resp => {
                this.rejectDfd({
                    reason: 'unauthorized',
                    errors: resp.data ? resp.data.errors : ['Invalid credentials'],
                });
                config.broadcast('auth:login-error', resp.data);
            },
        );
        return this.dfd.promise;
    }

    /**
     * Check if user is authenticated.
     * This uses the stored auth headers to check if the user is authenticated.
     * @returns {boolean}
     */
    userIsAuthenticated() {
        return this.retrieveData('auth_headers') && this.user.signedIn && !this.tokenHasExpired();
    }

    /**
     * Request password reset from API
     * @param {*} params password reset parameters
     * @param {CustomOptions} opts options
     * @returns {Promise<HttpResponse>}
     */
    requestPasswordReset(params, opts = {}) {
        const config = this.getConfig(opts.config);
        params.redirect_url = this.getResultOrValue(config.passwordResetSuccessUrl);
        if (opts.config != null) {
            params.config_name = opts.config;
        }

        return this.http(this.apiUrl(opts.config) + config.passwordResetPath, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(params),
        }).then(
            resp => {
                config.broadcast('auth:password-reset-request-success', params);
                return resp;
            },
            resp => {
                config.broadcast('auth:password-reset-request-error', resp.data);
                return resp;
            },
        );
    }

    /**
     * Update user password
     * @param {*} params password update parameters
     * @param {CustomOptions} opts options
     * @returns {Promise<HttpResponse>}
     */
    updatePassword(params, opts = {}) {
        const config = this.getConfig(opts.config);
        return this.http(this.apiUrl(opts.config) + config.passwordUpdatePath, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(params),
        }).then(
            resp => {
                config.broadcast('auth:password-change-success', resp.data);
                this.mustResetPassword = false;
                return resp;
            },
            resp => {
                config.broadcast('auth:password-change-error', resp.data);
                return resp;
            },
        );
    }

    /**
     * Update user account info
     * @param {*} params account update parameters
     * @param {CustomOptions} opts options
     * @returns {Promise<HttpResponse>}
     */
    updateAccount(params, opts = {}) {
        const config = this.getConfig(opts.config);
        return this.http(this.apiUrl(opts.config) + config.accountUpdatePath, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(params),
        }).then(
            resp => {
                const updateResponse = config.handleAccountUpdateResponse(resp.data);
                const curHeaders = this.retrieveData('auth_headers');

                Object.assign(this.user, updateResponse);

                // ensure any critical headers (uid + ?) that are returned in
                // the update response are updated appropriately in storage
                if (curHeaders) {
                    const newHeaders = {};
                    const ctx = {
                        token: this.user.auth_token,
                        clientId: this.user.client_id,
                        uid: this.user.uid,
                        expiry: this.user.expiry,
                    };
                    Object.entries(config.tokenFormat).forEach(([key, value]) => {
                        newHeaders[key] = interpolate(value, ctx);
                    });
                    this.setAuthHeaders(newHeaders);
                }
                config.broadcast('auth:account-update-success', resp.data);

                return resp;
            },
            resp => {
                config.broadcast('auth:account-update-error', resp.data);
                return resp;
            },
        );
    }

    /**
     * Permanently destroy a user's account.
     * @param {*} params account destroy parameters
     * @param {CustomOptions} opts options
     * @returns {Promise<HttpResponse>}
     */
    destroyAccount(params, opts = {}) {
        const config = this.getConfig(opts.config);
        return this.http(this.apiUrl(opts.config) + config.accountUpdatePath, {
            method: 'DELETE',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(params),
        }).then(
            resp => {
                this.invalidateTokens();
                config.broadcast('auth:account-destroy-success', resp.data);
                return resp;
            },
            resp => {
                config.broadcast('auth:account-destroy-error', resp.data);
                return resp;
            },
        );
    }

    /**
     * Open external auth provider in separate window, send requests for
     * credentials until api auth callback page responds.
     * @param {*} provider external auth provider
     * @param {CustomOptions} opts options
     * @returns {Promise<any>}
     */
    authenticate(provider, opts = {}) {
        if (this.dfd == null) {
            this.setConfigName(opts.config);
            this.initDfd();
            this.openAuthWindow(provider, opts);
        }

        return this.dfd.promise;
    }

    /**
     * Set the current config name
     */
    setConfigName(configName) {
        if (configName == null) {
            configName = defaultConfigName;
        }
        return this.persistData('currentConfigName', configName, configName);
    }

    /**
     * Open external window to authentication provider
     * @param {string} provider external auth provider
     * @param {CustomOptions} [opts] options
     * @returns {*}
     */
    openAuthWindow(provider, opts = {}) {
        const { omniauthWindowType, createPopup } = this.getConfig(opts.config);
        const authUrl = this.buildAuthUrl(omniauthWindowType, provider, opts);

        if (omniauthWindowType === 'newWindow') {
            this.requestCredentialsViaPostMessage(createPopup(authUrl));
        } else if (omniauthWindowType === 'inAppBrowser') {
            this.requestCredentialsViaExecuteScript(createPopup(authUrl));
        } else if (omniauthWindowType === 'sameWindow') {
            this.visitUrl(authUrl);
        } else {
            throw new Error(`Unsupported omniauthWindowType "${omniauthWindowType}"`);
        }
    }

    /**
     * Testing actual redirects is difficult. Stub this for testing
     * @param {string} url url to visit
     * @returns
     */
    // eslint-disable-next-line class-methods-use-this
    visitUrl(url) {
        return this.getConfig().navigate(url, true);
    }

    /**
     * Build url for authentication provider
     * @param {string} omniauthWindowType omniauthWindowType
     * @param {string} provider external auth provider
     * @param {CustomOptions} opts options
     * @returns {string}
     */
    buildAuthUrl(omniauthWindowType, provider, opts = {}) {
        const { apiUrl, authProviderPaths } = this.getConfig(opts.config);
        const authUrl = new URL(apiUrl + authProviderPaths[provider]);

        const params = {
            auth_origin_url: opts.auth_origin_url || window.location.href,
            ...opts.params,
            omniauth_window_type: omniauthWindowType,
        };

        Object.entries(params).forEach(([key, val]) => authUrl.searchParams.append(key, val));

        return authUrl.toString();
    }

    /**
     * Ping auth window to see if user has completed registration.
     * this method is recursively called until:
     * 1. user completes authentication
     * 2. user fails authentication
     * 3. auth window is closed
     * @param {Window} authWindow auth window
     * @returns {*}
     */
    requestCredentialsViaPostMessage(authWindow) {
        // user has closed the external provider's auth window without completing login.
        if (authWindow.closed) {
            return this.handleAuthWindowClose();
        }
        // still awaiting user input
        authWindow.postMessage('requestCredentials', '*');
        this.requestCredentialsPollingTimer = window.setTimeout(
            () => this.requestCredentialsViaPostMessage(authWindow),
            500,
        );
        return this.requestCredentialsPollingTimer;
    }

    /**
     * Handle inAppBrowser's executeScript flow
     * flow will complete if:
     * 1. user completes authentication
     * 2. user fails authentication
     * 3. inAppBrowser auth window is closed
     * @param {Window} authWindow auth window
     * @returns {*}
     */
    requestCredentialsViaExecuteScript(authWindow) {
        this.cancelOmniauthInAppBrowserListeners();
        const handleAuthWindowClose = this.handleAuthWindowClose.bind(this);
        const handleLoadStop = this.handleLoadStop.bind(this, authWindow);
        const handlePostMessage = this.handlePostMessage.bind(this);

        authWindow.addEventListener('loadstop', handleLoadStop);
        authWindow.addEventListener('exit', handleAuthWindowClose);
        authWindow.addEventListener('message', handlePostMessage);

        this.cancelOmniauthInAppBrowserListeners = () => {
            authWindow.removeEventListener('loadstop', handleLoadStop);
            authWindow.removeEventListener('exit', handleAuthWindowClose);
            return authWindow.addEventListener('message', handlePostMessage);
        };
        return this.cancelOmniauthInAppBrowserListeners;
    }

    /**
     * Responds to inAppBrowser window loads
     * @param {Window} authWindow auth window
     * @returns {*}
     */
    handleLoadStop(authWindow) {
        const _this = this;

        // favor InAppBrowser postMessage API if available, otherwise revert to returning directly via
        // the executeScript API, which is known to have limitations on payload size
        const remoteCode = `\
function performBestTransit() { \
var data = requestCredentials(); \
if (webkit && webkit.messageHandlers && webkit.messageHandlers.cordova_iab) { \
var dataWithDeliverMessage = Object.assign({}, data, { message: 'deliverCredentials' }); \
webkit.messageHandlers.cordova_iab.postMessage(JSON.stringify(dataWithDeliverMessage)); \
return 'postMessageSuccess'; \
} else { \
return data; \
} \
} \
performBestTransit();`;

        // eslint-disable-next-line consistent-return
        return authWindow.executeScript({ code: remoteCode }, response => {
            const data = response[0];
            if (data === 'postMessageSuccess') {
                // the standard issue postHandler will take care of the rest
                return authWindow.close();
            }
            if (data) {
                const ev = new Event('message');
                ev.data = data;
                _this.cancelOmniauthInAppBrowserListeners();
                window.dispatchEvent(ev);
                _this.initDfd();
                return authWindow.close();
            }
        });
    }

    /**
     * Responds to inAppBrowser window closes
     */
    handleAuthWindowClose() {
        this.cancel({
            reason: 'unauthorized',
            errors: ['User canceled login'],
        });
        this.cancelOmniauthInAppBrowserListeners();
        this.getConfig().broadcast('auth:window-closed');
    }

    /**
     * This needs to happen after a reflow so that the promise
     * can be rejected properly before it is destroyed.
     */
    resolveDfd() {
        if (!this.dfd) {
            return undefined;
        }

        this.dfd.resolve(this.user);

        return new Promise(resolve => {
            window.setTimeout(() => {
                this.dfd = null;
                resolve();
            });
        });
    }

    /**
     * Generates query string based on simple or complex object graphs
     * @param {Object} params object to be converted to query string
     * @param {string} [prefix] prefix to be added to query string
     * @returns {string}
     */
    buildQueryString(params, prefix) {
        const str = [];
        Object.entries(params).forEach(([key, val]) => {
            const k = prefix ? `${prefix}[${key}]` : key;
            const encoded = isObject(val) ? this.buildQueryString(val, k) : `${k}=${encodeURIComponent(val)}`;
            str.push(encoded);
        });
        return str.join('&');
    }

    /**
     * Parses raw query string parameters
     * @param {string} querystring raw querystring starting with ?
     * @returns {Object}
     */
    // eslint-disable-next-line class-methods-use-this
    parseQueryString(searchString) {
        const queryString = searchString.substring(1);
        const params = {};
        if (queryString) {
            const pairs = queryString.split('&');
            pairs.forEach(pair => {
                if (pair === '' || typeof pair === 'function') {
                    return;
                }
                const [key, val] = pair.split('=');
                params[decodeURIComponent(key)] = decodeURIComponent(val);
            });
        }
        return params;
    }

    /**
     * This is something that can be returned from 'resolve' methods
     * of pages that have restricted access
     * @param {CustomOptions} [opts] options
     * @returns {Promise<any>}
     */
    validateUser(opts = {}) {
        let configName = opts.config;

        if (this.dfd == null) {
            this.initDfd();

            // save trip to API if possible. assume that user is still signed
            // in if auth headers are present and token has not expired.
            if (this.getConfig(configName).transport === 'headers' && this.userIsAuthenticated()) {
                // user is still presumably logged in
                this.resolveDfd();
            } else {
                // token querystring is present. user most likely just came from
                // registration email link.
                const params = this.parseQueryString(window.location.search);

                // auth_token matches what is sent with postMessage, but supporting token for
                // backwards compatability
                const token = params.auth_token || params.token;

                if (token !== undefined) {
                    const clientId = params.client_id;
                    const { uid, expiry } = params;
                    configName = params.config;

                    // use the configuration that was used in creating
                    // the confirmation link
                    this.setConfigName(configName);

                    // check if redirected from password reset link
                    this.mustResetPassword = params.reset_password;

                    // check if redirected from email confirmation link
                    this.firstTimeLogin = params.account_confirmation_success;

                    // check if redirected from auth registration
                    this.oauthRegistration = params.oauth_registration;

                    // persist these values
                    this.setAuthHeaders(this.buildAuthHeaders({ token, clientId, uid, expiry }));

                    // build url base
                    let url = window.location.pathname;

                    // strip token-related qs from url to prevent re-use of these params
                    // on page refresh
                    [
                        'auth_token',
                        'token',
                        'client_id',
                        'uid',
                        'expiry',
                        'config',
                        'reset_password',
                        'account_confirmation_success',
                        'oauth_registration',
                    ].forEach(prop => delete params[prop]);

                    // append any remaining params, if any
                    if (Object.keys(params).length > 0) {
                        url += `?${this.buildQueryString(params)}`;
                    }

                    // redirect to target url
                    this.getConfig(configName).navigate(url);
                } else if (this.retrieveData('currentConfigName')) {
                    // token cookie is present. user is returning to the site, or
                    // has refreshed the page.
                    configName = this.retrieveData('currentConfigName');
                }

                // cookie might not be set, but forcing token validation has
                // been enabled
                if (this.getConfig().forceValidateToken) {
                    this.validateToken({ config: configName });
                } else if (this.getConfig(configName).transport === 'headers' && this.retrieveData('auth_headers')) {
                    // if token has expired, do not verify token with API
                    if (this.tokenHasExpired()) {
                        this.getConfig(configName).broadcast('auth:session-expired');
                        this.rejectDfd({
                            reason: 'unauthorized',
                            errors: ['Session expired.'],
                        });
                    } else {
                        // token has been saved in session var, token has not
                        // expired. must be verified with API.
                        this.validateToken({ config: configName });
                    }
                } else if (this.getConfig(configName).transport === 'cookies') {
                    // Note: We aren't specially handling the "Session expired" case like the headers transport flow.
                    // We don't really need to, the validateToken network call will 401 and trigger our re-authentication logic.
                    // The reason it makes sense to specially handle it in the headers transport flow is because you can save a network request.
                    this.validateToken({ config: configName });
                } else {
                    // new user session. will redirect to login
                    this.rejectDfd({
                        reason: 'unauthorized',
                        errors: ['No credentials'],
                    });
                    this.getConfig(configName).broadcast('auth:invalid');
                }
            }
        }

        return this.dfd.promise;
    }

    /**
     * Confirm that user's auth token is still valid.
     * @param {CustomOptions} [opts] options
     * @returns {Promise<HttpResponse>}
     */
    validateToken(opts = {}) {
        if (!this.tokenHasExpired()) {
            const config = this.getConfig(opts.config);
            return this.http(this.apiUrl(opts.config) + config.tokenValidationPath).then(
                resp => {
                    const authData = config.handleTokenValidationResponse(resp.data);
                    this.handleValidAuth(authData);

                    // broadcast event for first time login
                    if (this.firstTimeLogin) {
                        config.broadcast('auth:email-confirmation-success', this.user);
                    }

                    if (this.oauthRegistration) {
                        config.broadcast('auth:oauth-registration', this.user);
                    }

                    if (this.mustResetPassword) {
                        config.broadcast('auth:password-reset-confirm-success', this.user);
                    }

                    config.broadcast('auth:validation-success', this.user);

                    return resp;
                },
                resp => {
                    // broadcast event for first time login failure
                    if (this.firstTimeLogin) {
                        config.broadcast('auth:email-confirmation-error', resp.data);
                    }

                    if (this.mustResetPassword) {
                        config.broadcast('auth:password-reset-confirm-error', resp.data);
                    }

                    config.broadcast('auth:validation-error', resp.data);

                    // No data is no response, no response is no connection. Token cannot be destroyed if no connection
                    return this.rejectDfd(
                        {
                            reason: 'unauthorized',
                            errors: resp.data ? resp.data.errors : ['Unspecified error'],
                        },
                        true,
                    );
                },
            );
        }
        return this.rejectDfd({
            reason: 'unauthorized',
            errors: ['Expired credentials'],
        });
    }

    /**
     * Ensure token has not expired
     * @returns {boolean}
     */
    tokenHasExpired() {
        const expiry = this.getExpiry();
        const now = new Date().getTime();

        return expiry && expiry < now;
    }

    /**
     * Get expiry by method provided in config
     * @returns {number|null}
     */
    getExpiry() {
        return this.getConfig().parseExpiry(this.retrieveData('auth_headers') || {});
    }

    /**
     * This service attempts to cache auth tokens, but sometimes we
     * will want to discard saved tokens. examples include:
     * 1. login failure
     * 2. token validation failure
     * 3. user logs out
     * @returns {*}
     */
    invalidateTokens() {
        // cannot delete user object for scoping reasons. instead, delete
        // all keys on object.
        // eslint-disable-next-line no-restricted-syntax,guard-for-in
        for (const key in this.user) {
            delete this.user[key];
        }

        // remove any assumptions about current configuration
        this.deleteData('currentConfigName');

        if (this.timer != null) {
            window.clearInterval(this.timer);
        }

        // kill cookies, otherwise session will resume on page reload
        // setting this value to null will force the validateToken method
        // to re-validate credentials with api server when validate is called
        return this.deleteData('auth_headers');
    }

    /**
     * Destroy auth token on server, destroy user auth credentials
     * @param {CustomOptions} [opts] options
     * @returns {Promise<HttpResponse>}
     */
    signOut(opts = {}) {
        const config = this.getConfig(opts.config);
        return this.http(this.apiUrl(opts.config) + config.signOutUrl, { method: 'DELETE' }).then(
            resp => {
                this.invalidateTokens();
                config.broadcast('auth:logout-success');
                return resp;
            },
            resp => {
                this.invalidateTokens();
                config.broadcast('auth:logout-error', resp.data);
                return resp;
            },
        );
    }

    /**
     * Handle successful authentication
     * @param {Object} user user object
     * @param {boolean} [setHeaders] set auth header
     * @returns {Promise<any>}
     */
    handleValidAuth(user, setHeaders) {
        // cancel any pending postMessage checks
        if (setHeaders == null) {
            setHeaders = false;
        }
        if (this.requestCredentialsPollingTimer != null) {
            window.clearTimeout(this.requestCredentialsPollingTimer);
        }

        // cancel any inAppBrowser listeners
        this.cancelOmniauthInAppBrowserListeners();

        // must extend existing object for scoping reasons
        Object.assign(this.user, user);

        // add shortcut to determine user auth status
        this.user.signedIn = true;
        this.user.configName = this.getCurrentConfigName();

        // postMessage will not contain header. must save headers manually.
        if (setHeaders) {
            this.setAuthHeaders(
                this.buildAuthHeaders({
                    token: this.user.auth_token,
                    clientId: this.user.client_id,
                    uid: this.user.uid,
                    expiry: this.user.expiry,
                }),
            );
        }

        // fulfill promise
        return this.resolveDfd();
    }

    /**
     * Configure auth token format
     * @param {Object} ctx context
     * @param {CustomOptions} [opts] options
     * @returns {Object}
     */
    buildAuthHeaders(ctx, opts = {}) {
        const headers = {};

        const tokenFormat = this.getConfig(opts.config).tokenFormat;
        Object.entries(tokenFormat).forEach(([key, val]) => {
            headers[key] = interpolate(val, ctx);
        });

        return headers;
    }

    /**
     * Abstract persistent data store
     * @param {string} key key
     * @param {string} val value
     * @param {string} [configName] config name
     * @returns {*}
     */
    persistData(key, val, configName) {
        const { storage, transport, cookieOps } = this.getConfig(configName);

        if (transport === 'cookies') {
            return undefined;
        }

        if (storage instanceof Object) {
            return storage.persistData(key, val);
        }

        switch (storage) {
            case 'localStorage':
                return window.localStorage.setItem(key, JSON.stringify(val));
            case 'sessionStorage':
                return window.sessionStorage.setItem(key, JSON.stringify(val));
            default:
                return Cookies.set(key, val, cookieOps);
        }
    }

    /**
     * Abstract persistent data retrieval
     * @param {string} key key
     * @returns {*}
     */
    retrieveData(key) {
        const { storage, transport } = this.getConfig();

        if (transport === 'cookies') {
            return undefined;
        }

        try {
            if (storage instanceof Object) {
                return storage.retrieveData(key);
            }
            switch (storage) {
                case 'localStorage':
                    return JSON.parse(window.localStorage.getItem(key));
                case 'sessionStorage':
                    return JSON.parse(window.sessionStorage.getItem(key));
                default:
                    return Cookies.getJSON(key);
            }
        } catch (e) {
            // gracefully handle if JSON parsing
            if (e instanceof SyntaxError) {
                return null;
            }
            throw e;
        }
    }

    /**
     * Abstract persistent data removal
     * @param {string} key key
     * @returns {*}
     */
    deleteData(key) {
        const { storage, transport, cookieOps } = this.getConfig();

        if (transport === 'cookies') {
            return undefined;
        }

        if (storage instanceof Object) {
            storage.deleteData(key);
        }

        switch (storage) {
            case 'localStorage':
                return window.localStorage.removeItem(key);
            case 'sessionStorage':
                return window.sessionStorage.removeItem(key);
            default: {
                const options = { path: cookieOps.path };

                if (cookieOps.domain !== undefined) {
                    options.domain = cookieOps.domain;
                }

                return Cookies.remove(key, options);
            }
        }
    }

    /**
     * Persist authentication token, client id, expiry, uid
     * @param {AuthHeaders} headers auth headers
     */
    setAuthHeaders(headers) {
        const newHeaders = {
            ...(this.retrieveData('auth_headers') || {}),
            ...headers,
        };
        this.persistData('auth_headers', newHeaders);

        const expiry = this.getExpiry();
        const now = new Date().getTime();

        if (expiry > now) {
            if (this.timer != null) {
                window.clearInterval(this.timer);
            }

            this.timer = window.setInterval(
                () => this.validateUser({ config: this.getSavedConfig() }),
                parseInt(expiry - now, 10),
            );
        }
    }

    /**
     * Init a ES6 style promise deferred object
     */
    initDfd() {
        this.dfd = {};
        const promise = new Promise((resolve, reject) => {
            this.dfd.resolve = resolve;
            this.dfd.reject = reject;
        });
        this.dfd.promise = promise;
        return this.dfd.promise;
    }

    /**
     * Failed login => invalidate auth header and reject promise.
     * deferred object must be destroyed after reflow.
     * @param {{ reason: string; errors: string[] }} reason reason
     * @param {boolean} [invalidateTokens] invalidate tokens
     * @returns {*}
     */
    rejectDfd(reason, invalidateTokens = true) {
        if (invalidateTokens) {
            this.invalidateTokens();
        }

        if (this.dfd != null) {
            this.dfd.reject(reason);

            // must nullify after reflow so promises can be rejected
            return new Promise(resolve => {
                window.setTimeout(() => {
                    this.dfd = null;
                    resolve();
                });
            });
        }

        return undefined;
    }

    /**
     * Use proxy for IE
     * @param {string} [configName] config name
     * @returns {string}
     */
    apiUrl(configName) {
        const config = this.getConfig(configName);
        if (config.proxyIf()) {
            return config.proxyUrl;
        }
        return config.apiUrl;
    }

    /**
     * Get config
     * @param {string} [name] config name
     * @returns {Config}
     */
    getConfig(name) {
        return configs[this.getCurrentConfigName(name)];
    }

    /**
     * If value is a method, call the method. otherwise return the argument itself
     * @param {*} arg argument
     * @returns {*}
     */
    // eslint-disable-next-line class-methods-use-this
    getResultOrValue(arg) {
        if (typeof arg === 'function') {
            return arg();
        }
        return arg;
    }

    /**
     * A config name will be return in the following order of precedence:
     * 1. matches arg
     * 2. saved from past authentication
     * 3. first available config name
     * @param {string} [name] config name
     * @returns {string}
     */
    getCurrentConfigName(name) {
        return name || this.getSavedConfig();
    }

    /**
     * Can't rely on retrieveData because it will cause a recursive loop
     * if config hasn't been initialized. instead find first available
     * value of 'defaultConfigName'. searches the following places in
     * this priority:
     * 1. localStorage
     * 2. sessionStorage
     * 3. cookies
     * 4. default (first available config)
     * @returns {string}
     */
    getSavedConfig() {
        let c = null;
        const key = 'currentConfigName';

        if (this.hasLocalStorage() && c == null) {
            c = JSON.parse(window.localStorage.getItem(key));
        } else if (this.hasSessionStorage() && c == null) {
            c = JSON.parse(window.sessionStorage.getItem(key));
        } else if (c == null) {
            c = Cookies.get(key);
        }

        return c || defaultConfigName;
    }

    /**
     * Has SessionStorage available
     * @returns {boolean}
     */
    hasSessionStorage() {
        if (this._hasSessionStorage == null) {
            this._hasSessionStorage = false;
            // trying to call setItem will
            // throw an error if sessionStorage is disabled
            try {
                window.sessionStorage.setItem('DeviceTokenAuthClient-test', 'DeviceTokenAuthClient-test');
                window.sessionStorage.removeItem('DeviceTokenAuthClient-test');
                this._hasSessionStorage = true;
            } catch (error) {
                this._hasSessionStorage = false;
            }
        }

        return this._hasSessionStorage;
    }

    /**
     * Has LocalStorage available
     * @returns {boolean}
     */
    hasLocalStorage() {
        if (this._hasLocalStorage == null) {
            this._hasLocalStorage = false;
            // trying to call setItem will
            // throw an error if localStorage is disabled
            try {
                window.localStorage.setItem('DeviceTokenAuthClient-test', 'DeviceTokenAuthClient-test');
                window.localStorage.removeItem('DeviceTokenAuthClient-test');
                this._hasLocalStorage = true;
            } catch (error) {
                this._hasLocalStorage = false;
            }
        }

        return this._hasLocalStorage;
    }
}
