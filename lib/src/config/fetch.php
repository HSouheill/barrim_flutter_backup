<?php
// $username = 'ali.sali.s'; // Your GeoNames username

function fetchData($url)
{
    $response = @file_get_contents($url);
    if ($response === FALSE) {
        return json_encode(['error' => 'Unable to fetch data']);
    } else {
        return $response;
    }
}

if ($_GET['action'] == 'getCountries') {
    $url = "http://api.geonames.org/countryInfoJSON?username=$username";
    echo fetchData($url); // Directly return the API response
}

if ($_GET['action'] == 'getGovernorates' && isset($_GET['countryId'])) {
    $countryId = $_GET['countryId'];
    // Fetch governorates (ADM2)
    $url = "http://api.geonames.org/childrenJSON?geonameId=$countryId&username=$username";
    echo fetchData($url); // Directly return the API response
}


if ($_GET['action'] == 'getJudiciaries' && isset($_GET['regionId'])) {
    $regionId = $_GET['regionId'];
    // Fetch judiciaries (ADM3)
    $url = "http://api.geonames.org/childrenJSON?geonameId=$regionId&username=$username";
    echo fetchData($url); // Directly return the API response
}
