# API

Foreach OS service, make directory with name service
Foreach supported (sub)version, make a version module 'v<version>.pm'
  A . in the version has to be replaced by DOT ; eg v3.1 should be v3DOT1.pm
Every version module has simple syntax:
* a `VERSION` readonly with the version
* an `API_DATA` readonly hashref with
  * key: method name
  * value: arrayref with args
    * method: GET/PUT/POST/DELETE/PATCH (TODO:, end with `%function` for postprocessing the result)
    * url/endpoint (w/o version)
    * remainder are POST data
      * start with `?`: optional (default: mandatory)
      * end with `%type`: convert to type (default string)
      * url can have `{name}` variables, will be replaced by corresponding arguments and not passed to POST

Methods can be called as follows:
* directly from base auth, using `api_<service>_<method>` method name
* instantiate a service instance via `service`, and then call `method`

If no endpoint is found, try to discover it.
If no version is set, use `CURRENT` from version API

# Flow

* Call method with args
  * AUTOLOAD in Client::API
    * retrieve from API::Magic
      * looks for description/api data in API::<service>::<version>
    * process_args from API::Magic
      * preps request instance based on data and args
      * executes and returns the request with rpc(request) call

# TODO

Generate / prefill the value list from the API documentation.
