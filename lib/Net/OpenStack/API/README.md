# API

The API service modules and pods are generated using the `genapi/gen.pl` script.
See the `genapi/README` for details how to add new service and/or methods.

# Methods

Methods can be called as follows:
* directly from base auth, using `api_<service>_<method>` method name
* TODO: instantiate a service instance via `service`, and then call `method`

TODO: If no endpoint is found, try to discover it.
TODO: If no version is set, use `CURRENT` from version API

# Code Flow

* Call method with args
  * AUTOLOAD in Client::API
    * retrieve from API::Magic
      * looks for description/api data in API::<service>::<version>
    * process_args from API::Magic
      * preps request instance based on data and args
      * executes and returns the request with rest(request) call

# TODO

Generate / prefill the value list from the API documentation.
