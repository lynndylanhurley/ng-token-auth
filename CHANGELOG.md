<a name="0.0.28"></a>
# 0.0.28 (2015-08-09)

## Features

- **Improved OAuth Flow**: Supports new OAuth window flows, allowing options for `sameWindow`, `newWindow`, and `inAppBrowser`

## Breaking Changes

- `forceHardReload` has been removed in favor of `omniauthWindowType`. The new behavior now defaults to `sameWindow` mode, whereas the previous implementation mimicked the functionality of `newWindow`. This was changed due to limitations with the `postMessage` API support in popular browsers, as well as feedback from user-experience testing.