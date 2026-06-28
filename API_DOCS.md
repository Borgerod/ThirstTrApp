# APIs

## PLANTS - perenual

Plant species reference data (taxonomy, care, pests, hardiness) — used to identify a plant on add and to enrich its care guide. Client: `lib/services/perenual_api.dart`. Key stored in Settings (`PerenualApi.apiKey`).

### Summary

<details id="summary"> 
    <summary>read more</summary>

<br>

**src**
https://perenual.com/docs/plant-open-api#/

<br>

**Description**

| Endpoint                   | Method              | Gets                                         | Used for / where                                                                                      |
| -------------------------- | ------------------- | -------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `/v2/species-list`         | `speciesList()`     | Paged, searchable species list               | Add-plant species search — `species_search_screen.dart:35`                                            |
| `/v2/species/details/{id}` | `speciesDetails()`  | Full details for one species                 | Enrich picked species (`enrichedSpecies()`), feeds plant detail — `species_search_screen.dart:50`     |
| `/species-care-guide-list` | `careGuide()`       | Watering/sunlight/pruning sections           | Merged into species by `enrichedSpecies()`, shown in care-guide card — `plant_detail_screen.dart:177` |
| `/pest-disease-list`       | `pestDiseaseList()` | Common pests/diseases (optional per species) | Defined in client; **no UI caller yet**                                                               |
| `/hardiness-map`           | `hardinessMapUrl()` | Embeddable hardiness-zone map URL            | Defined in client; **no UI caller yet**                                                               |

<br>

**base**

```ts
const base_url = "https://perenual.com/api";
```

**Extentions**

```ts
const species_list = "/v2/species-list";

const species_details = "/v2/species/details/{id}";

const pest_disease_list = "/pest-disease-list";

const species_care_guide_list = "/species-care-guide-list";

const species_hardiness_map = "/species-care-guide-list";
```

</details>

<!--

> SPECIES-LIST

-->

### /v2/species-list

<details id="species-list"> 
    <summary>
    read more
    </summary> 
    
## Hidden heading
```ts 
const species_list = "/v2/species-list";
```

_Content_for_species_care_guide_list_here_

### cURL (Placeholder Variables)

```bash
curl -X GET \
  "https://perenual.com/api/v2/species-list?key=${API_KEY}&q=${QUERY}&page=${PAGE}&order=${ORDER}&edible=${EDIBLE}&indoor=${INDOOR}&poisonous=${POISONOUS}&cycle=${CYCLE}&watering=${WATERING}&sunlight=${SUNLIGHT}&hardiness=${HARDINESS}" \
  -H "Accept: application/json"
```

### cURL (Example Values)

```bash
curl -X GET \
  "https://perenual.com/api/v2/species-list?key=YOUR_API_KEY&q=monstera&page=1&order=asc&indoor=1&hardiness=4-8" \
  -H "Accept: application/json"
```

### TypeScript

```ts
const response = await fetch(
  `https://perenual.com/api/v2/species-list?key=${apiKey}&q=${query}&page=${page}&order=${order}&edible=${edible}&indoor=${indoor}&poisonous=${poisonous}&cycle=${cycle}&watering=${watering}&sunlight=${sunlight}&hardiness=${hardiness}`,
  {
    method: "GET",
    headers: {
      Accept: "application/json",
    },
  },
);
```

### Params

| Name        | Type     | Required | Description                                        |
| ----------- | -------- | -------- | -------------------------------------------------- |
| `key`       | `string` | ✅       | API key.                                           |
| `q`         | `string` | ❌       | Search query (e.g. `"monstera"`).                  |
| `page`      | `number` | ❌       | 1-based page index. Default: `1`.                  |
| `order`     | `string` | ❌       | Sort order.                                        |
| `edible`    | `0 \| 1` | ❌       | Filter edible plants (`1` = true, `0` = false).    |
| `indoor`    | `0 \| 1` | ❌       | Filter indoor plants (`1` = true, `0` = false).    |
| `poisonous` | `0 \| 1` | ❌       | Filter poisonous plants (`1` = true, `0` = false). |
| `cycle`     | `string` | ❌       | Plant life cycle filter.                           |
| `watering`  | `string` | ❌       | Watering requirement filter.                       |
| `sunlight`  | `string` | ❌       | Sunlight requirement filter.                       |
| `hardiness` | `string` | ❌       | USDA hardiness range (e.g. `"4-8"`).               |

```ts
interface SpeciesListParams {
  key: string;
  q?: string;
  page?: number;
  order?: string;
  edible?: 0 | 1;
  indoor?: 0 | 1;
  poisonous?: 0 | 1;
  cycle?: string;
  watering?: string;
  sunlight?: string;
  hardiness?: string;
}
```

### Headers

| Name     | Type               | Required | Description            |
| -------- | ------------------ | -------- | ---------------------- |
| `Accept` | `application/json` | ❌       | Response content type. |

```ts
interface SpeciesListHeaders {
  Accept?: "application/json";
}
```

### Payload

GET requests do not include a request body.

```ts
type SpeciesListPayload = never;
```

</details>

<!--

> SPECIES-DETAILS

-->

### /v2/species/details/{id}

<details id="species-details"> 
<summary>
read more
</summary>

```ts
const species_details = "/v2/species/details/{id}";
```

_Content_for_species_care_guide_list_here_

### cURL (Placeholder Variables)

```bash
curl -X GET \
  "https://perenual.com/api/v2/species/details/${ID}?key=${API_KEY}" \
  -H "Accept: application/json"
```

### cURL (Example Values)

```bash
curl -X GET \
  "https://perenual.com/api/v2/species/details/1?key=YOUR_API_KEY" \
  -H "Accept: application/json"
```

### TypeScript

```ts
const response = await fetch(
  `https://perenual.com/api/v2/species/details/${id}?key=${apiKey}`,
  {
    method: "GET",
    headers: {
      Accept: "application/json",
    },
  },
);
```

### Params

| Name  | Type      | Required | Description              |
| ----- | --------- | -------- | ------------------------ |
| `id`  | `integer` | ✅       | Species ID (path param). |
| `key` | `string`  | ✅       | API key.                 |

```ts
interface SpeciesDetailsParams {
  id: number;
  key: string;
}
```

### Headers

| Name     | Type               | Required | Description            |
| -------- | ------------------ | -------- | ---------------------- |
| `Accept` | `application/json` | ❌       | Response content type. |

```ts
interface SpeciesDetailsHeaders {
  Accept?: "application/json";
}
```

### Payload

GET requests do not include a request body.

```ts
type SpeciesDetailsPayload = never;
```

### Response (200)

```ts
interface SpeciesDetailsResponse {
  id: number;
  common_name: string;
  scientific_name: string[];
  other_name: string[];
  family: string;
  hybrid: number;
  authority: string;
  subspecies: string;
  cultivar: string;
  variety: string;
  species_epithet: string;
  genus: string;
  origin: string[];
  type: string;
  dimensions: {
    type: string;
    min_value: number;
    max_value: number;
    unit: string;
  }[];
  cycle: string;
  attracts: string[];
  propagation: string[];
  hardiness: {
    min: string;
    max: string;
  };
  hardiness_location: {
    full_url: string;
    full_iframe: string;
  };
  watering: string;
  watering_general_benchmark: {
    value: string;
    unit: string;
  };
  plant_anatomy: {
    part: string;
    color: string[];
  }[];
  sunlight: string[];
  pruning_month: string[];
  pruning_count: {
    amount: number;
    interval: string;
  };
  seeds: number;
  maintenance: string;
  care_guides: string;
  soil: string[];
  growth_rate: string;
  drought_tolerant: number;
  salt_tolerant: number;
  thorny: number;
  invasive: number;
  tropical: number;
  indoor: number;
  care_level: string;
  pest_susceptibility: string[];
  flowers: number;
  flowering_season: string;
  cones: number;
  fruits: number;
  edible_fruit: number;
  harvest_season: string;
  leaf: number;
  edible_leaf: number;
  cuisine: number;
  medicinal: number;
  poisonous_to_humans: number;
  poisonous_to_pets: number;
  description: string;
  default_image: {
    license: number;
    license_name: string;
    license_url: string;
    original_url: string;
    regular_url: string;
    medium_url: string;
    small_url: string;
    thumbnail: string;
  };
  other_images: {
    license: number;
    license_name: string;
    license_url: string;
    original_url: string;
    regular_url: string;
    medium_url: string;
    small_url: string;
    thumbnail: string;
  }[];
  xWateringQuality: string[];
  xWateringPeriod: string[];
  xWateringAvgVolumeRequirement: string[];
  xWateringDepthRequirement: {
    unit: string;
    value: string;
  };
  xWateringBasedTemperature: {
    unit: string;
    min: number;
    max: number;
  };
  xWateringPhLevel: {
    min: number;
    max: number;
  };
  xSunlightDuration: {
    min: string;
    max: string;
    unit: string;
  };
  xTemperatureTolence: string[];
  xPlantSpacingRequirement: {
    unit: string;
    value: number;
  };
}
```

</details>

<!--

> PEST-DISEASE-LIST

 -->

### /pest-disease-list

<details id="pest-disease-list"> 
<summary>
read more
</summary>

```ts
const pest_disease_list = "/pest-disease-list";
```

_Content_for_species_care_guide_list_here_

### cURL (Placeholder Variables)

```bash
curl -X GET \
  "https://perenual.com/api/pest-disease-list?key=${API_KEY}&q=${QUERY}&page=${PAGE}&type=${TYPE}&id=${ID}" \
  -H "Accept: application/json"
```

### cURL (Example Values)

```bash
curl -X GET \
  "https://perenual.com/api/pest-disease-list?key=YOUR_API_KEY&q=aphid&page=1&type=pest" \
  -H "Accept: application/json"
```

### TypeScript

```ts
const response = await fetch(
  `https://perenual.com/api/pest-disease-list?key=${apiKey}&q=${query}&page=${page}&type=${type}&id=${id}`,
  {
    method: "GET",
    headers: {
      Accept: "application/json",
    },
  },
);
```

### Params

| Name   | Type      | Required | Description                                                      |
| ------ | --------- | -------- | ---------------------------------------------------------------- |
| `key`  | `string`  | ✅       | API key.                                                         |
| `q`    | `string`  | ❌       | Search query.                                                    |
| `page` | `integer` | ❌       | 1-based page index. Each page contains 30 results. Default: `1`. |
| `type` | `string`  | ❌       | Filter by type.                                                  |
| `id`   | `integer` | ❌       | Filter by specific disease/pest ID.                              |

```ts
interface PestDiseaseListParams {
  key: string;
  q?: string;
  page?: number;
  type?: string;
  id?: number;
}
```

### Headers

| Name     | Type               | Required | Description            |
| -------- | ------------------ | -------- | ---------------------- |
| `Accept` | `application/json` | ❌       | Response content type. |

```ts
interface PestDiseaseListHeaders {
  Accept?: "application/json";
}
```

### Payload

GET requests do not include a request body.

```ts
type PestDiseaseListPayload = never;
```

### Response (200)

```ts
interface PestDiseaseListResponse {
  data: {
    id: number;
    common_name: string;
    scientific_name: string;
    other_name: string;
    family: string;
    description: {
      subtitle: string;
      description: string;
    }[];
    solution: {
      subtitle: string;
      description: string;
    }[];
    host: string[];
    images: {
      license: number;
      license_name: string;
      license_url: string;
      original_url: string;
      regular_url: string;
      medium_url: string;
      small_url: string;
      thumbnail: string;
    }[];
  }[];
  meta: {
    to: number;
    per_page: number;
    current_page: number;
    from: number;
    last_page: number;
    total: number;
  };
}
```

</details>

<!--

> SPECIES-CARE-GUIDE-LIST-1

 -->

### /species-care-guide-list

<details id="species-care-guide-list-1"> 
<summary>
read more
</summary>

```ts
const species_care_guide_list = "/species-care-guide-list";
```

_Content_for_species_care_guide_list_here_

### cURL (Placeholder Variables)

```bash
curl -X GET \
  "https://perenual.com/api/species-care-guide-list?key=${API_KEY}&q=${QUERY}&page=${PAGE}&species_id=${SPECIES_ID}&type=${TYPE}" \
  -H "Accept: application/json"
```

### cURL (Example Values)

```bash
curl -X GET \
  "https://perenual.com/api/species-care-guide-list?key=YOUR_API_KEY&page=1&species_id=1&type=watering" \
  -H "Accept: application/json"
```

### TypeScript

```ts
const response = await fetch(
  `https://perenual.com/api/species-care-guide-list?key=${apiKey}&q=${query}&page=${page}&species_id=${speciesId}&type=${type}`,
  {
    method: "GET",
    headers: {
      Accept: "application/json",
    },
  },
);
```

### Params

| Name         | Type      | Required | Description                                                           |
| ------------ | --------- | -------- | --------------------------------------------------------------------- |
| `key`        | `string`  | ✅       | API key.                                                              |
| `q`          | `string`  | ❌       | Search query.                                                         |
| `page`       | `integer` | ❌       | 1-based page index. Each page contains 30 results. Default: `1`.      |
| `species_id` | `integer` | ❌       | Filter by species ID.                                                 |
| `type`       | `string`  | ❌       | Care guide type. Available values: `watering`, `sunlight`, `pruning`. |

```ts
interface SpeciesCareGuideListParams {
  key: string;
  q?: string;
  page?: number;
  species_id?: number;
  type?: "watering" | "sunlight" | "pruning";
}
```

### Headers

| Name     | Type               | Required | Description            |
| -------- | ------------------ | -------- | ---------------------- |
| `Accept` | `application/json` | ❌       | Response content type. |

```ts
interface SpeciesCareGuideListHeaders {
  Accept?: "application/json";
}
```

### Payload

GET requests do not include a request body.

```ts
type SpeciesCareGuideListPayload = never;
```

### Response (200)

```ts
interface SpeciesCareGuideListResponse {
  data: {
    id: number;
    species_id: number;
    common_name: string;
    scientific_name: string;
    section: {
      id: number;
      type: string;
      description: string;
    }[];
  }[];
  meta: {
    to: number;
    per_page: number;
    current_page: number;
    from: number;
    last_page: number;
    total: number;
  };
}
```

</details>

<!--

> SPECIES-CARE-GUIDE-LIST-2

 -->

### /hardiness-map

<details id="species-care-guide-list-2"> 
<summary>
read more
</summary>

```ts
const species_hardiness_map = "/hardiness-map";
```

_Content_for_species_care_guide_list_here_

### cURL (Placeholder Variables)

```bash
curl -X GET \
  "https://perenual.com/api/hardiness-map?key=${API_KEY}&species_id=${SPECIES_ID}" \
  -H "Accept: text/html"
```

### cURL (Example Values)

```bash
curl -X GET \
  "https://perenual.com/api/hardiness-map?key=YOUR_API_KEY&species_id=1" \
  -H "Accept: text/html"
```

### TypeScript

```ts
const response = await fetch(
  `https://perenual.com/api/hardiness-map?key=${apiKey}&species_id=${speciesId}`,
  {
    method: "GET",
    headers: {
      Accept: "text/html",
    },
  },
);
```

### Params

| Name         | Type      | Required | Description           |
| ------------ | --------- | -------- | --------------------- |
| `key`        | `string`  | ✅       | API key.              |
| `species_id` | `integer` | ❌       | Filter by species ID. |

```ts
interface HardinessMapParams {
  key: string;
  species_id?: number;
}
```

### Headers

| Name     | Type        | Required | Description            |
| -------- | ----------- | -------- | ---------------------- |
| `Accept` | `text/html` | ❌       | Response content type. |

```ts
interface HardinessMapHeaders {
  Accept?: "text/html";
}
```

### Payload

GET requests do not include a request body.

```ts
type HardinessMapPayload = never;
```

### Response (200)

Returns an HTML string containing a canvas element for the hardiness map.

```ts
type HardinessMapResponse = string;
```

```html
<canvas
  id="myCanvas"
  style="width: 100%; height: 100%;"
  width="1000"
  height="505"
></canvas>
```

</details>

### schemas

<details id="schemas"> 
<summary>read more</summary>

#### SpeciesList

<a href="#species-list">↑ Jump to /v2/species-list</a>

```ts
interface SpeciesList {
  id: number;
  common_name: string;
  scientific_name: string[];
  other_name: string[];
  family: string;
  hybrid: string;
  authority: string;
  subspecies: string;
  cultivar: string;
  variety: string;
  species_epithet: string;
  genus: string;
  default_image: SpeciesImage;
}
```

#### SpeciesDetail

<a href="#species-details">↑ Jump to /v2/species/details/{id}</a>

```ts
interface SpeciesDetail {
  id: number;
  common_name: string;
  scientific_name: string[];
  other_name: string[];
  family: string;
  hybrid: string;
  authority: string;
  subspecies: string;
  cultivar: string;
  variety: string;
  species_epithet: string;
  genus: string;
  origin: string[];
  type: string;
  dimensions: {
    type: string;
    min_value: number;
    max_value: number;
    unit: string;
  }[];
  cycle: string;
  attracts: string[];
  propagation: string[];
  hardiness: {
    min: string;
    max: string;
  };
  hardiness_location: {
    full_url: string;
    full_iframe: string;
  };
  watering: string;
  watering_general_benchmark: {
    value: string;
    unit: string;
  };
  plant_anatomy: {
    part: string;
    color: string[];
  }[];
  sunlight: string[];
  pruning_month: string[];
  pruning_count: {
    amount: number;
    interval: string;
  };
  seeds: number;
  maintenance: string;
  care_guides: string;
  soil: string[];
  growth_rate: string;
  drought_tolerant: number;
  salt_tolerant: number;
  thorny: number;
  invasive: number;
  tropical: number;
  indoor: number;
  care_level: string;
  pest_susceptibility: string[];
  flowers: number;
  flowering_season: string;
  cones: number;
  fruits: number;
  edible_fruit: number;
  harvest_season: string;
  leaf: number;
  edible_leaf: number;
  cuisine: number;
  medicinal: number;
  poisonous_to_humans: number;
  poisonous_to_pets: number;
  description: string;
  default_image: SpeciesImage;
  other_images: SpeciesImage[];
  xWateringQuality: string[];
  xWateringPeriod: string[];
  xWateringAvgVolumeRequirement: string[];
  xWateringDepthRequirement: {
    unit: string;
    value: string;
  };
  xWateringBasedTemperature: {
    unit: string;
    min: number;
    max: number;
  };
  xWateringPhLevel: {
    min: number;
    max: number;
  };
  xSunlightDuration: {
    min: string;
    max: string;
    unit: string;
  };
  xTemperatureTolence: string[];
  xPlantSpacingRequirement: {
    unit: string;
    value: number;
  };
}
```

#### SpeciesImage

<a href="#species-list">↑ Jump to /v2/species-list</a> · <a href="#species-details">↑ Jump to /v2/species/details/{id}</a>

```ts
interface SpeciesImage {
  license: number;
  license_name: string;
  license_url: string;
  original_url: string;
  regular_url: string;
  medium_url: string;
  small_url: string;
  thumbnail: string;
}
```

#### Disease

<a href="#pest-disease-list">↑ Jump to /pest-disease-list</a>

```ts
interface Disease {
  id: number;
  common_name: string;
  scientific_name: string;
  other_name: string;
  family: string;
  description: {
    subtitle: string;
    description: string;
  }[];
  solution: {
    subtitle: string;
    description: string;
  }[];
  host: string[];
  images: DiseaseImage[];
}
```

#### DiseaseImage

<a href="#pest-disease-list">↑ Jump to /pest-disease-list</a>

```ts
interface DiseaseImage {
  license: number;
  license_name: string;
  license_url: string;
  original_url: string;
  regular_url: string;
  medium_url: string;
  small_url: string;
  thumbnail: string;
}
```

#### SpeciesGuide

<a href="#species-care-guide-list-1">↑ Jump to /species-care-guide-list</a>

```ts
interface SpeciesGuide {
  id: number;
  species_id: number;
  common_name: string;
  scientific_name: string;
  section: SpeciesGuideSection[];
}
```

#### SpeciesGuideSection

<a href="#species-care-guide-list-1">↑ Jump to /species-care-guide-list</a>

```ts
interface SpeciesGuideSection {
  id: number;
  type: string;
  description: string;
}
```

#### PaginationMeta

<a href="#pest-disease-list">↑ Jump to /pest-disease-list</a> · <a href="#species-care-guide-list-1">↑ Jump to /species-care-guide-list</a>

```ts
interface PaginationMeta {
  to: number;
  per_page: number;
  current_page: number;
  from: number;
  last_page: number;
  total: number;
}
```

## WEATHER - open-meteo

Outdoor climate data: a current-weather snapshot used to nudge watering schedules (hot/dry/windy = water more often), plus the geocoding lookup that turns the user's home city into coordinates (this is the app's user-location functionality — Open-Meteo, no device GPS). No API key required. Client: `lib/services/weather_api.dart`. Forecast drives `weatherProvider` → `scheduler.dart` watering factor; only fetched when a home location is set and `useWeatherAdjustment` is on.

### Summary

<details id="weather-summary">
    <summary>read more</summary>

<br>

**src**
https://open-meteo.com/en/docs

<br>

**Description**

| Endpoint                      | Method              | Gets                                           | Used for / where                                                                                   |
| ----------------------------- | ------------------- | ---------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `/v1/forecast`                | `current(lat, lon)` | Current temp, humidity, wind + last-24h precip | Adjust watering interval — `providers.dart:113` (`weatherProvider`) → `scheduler.dart`             |
| `/v1/search` (geocoding host) | `geocode(name)`     | Lat/lon candidates for a city name             | User-location: home-city search in Settings — `settings_screen.dart:181`, saved on `AppSettings`   |

<br>

**base**

```ts
const forecast_base = "https://api.open-meteo.com";
const geocoding_base = "https://geocoding-api.open-meteo.com";
```

**Extentions**

```ts
const forecast = "/v1/forecast";

const geocoding_search = "/v1/search";
```

No API key. Free for non-commercial use.

</details>

<!--

> FORECAST

-->

### /v1/forecast

<details id="weather-forecast">
<summary>read more</summary>

```ts
const forecast = "https://api.open-meteo.com/v1/forecast";
```

Returns current weather + daily precipitation for a coordinate. The app maps the response into a `WeatherSnapshot` whose `wateringFactor` scales the base watering interval.

### cURL (Placeholder Variables)

```bash
curl -X GET \
  "https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,relative_humidity_2m,wind_speed_10m&daily=precipitation_sum&past_days=1&forecast_days=1&timezone=auto" \
  -H "Accept: application/json"
```

### cURL (Example Values)

```bash
curl -X GET \
  "https://api.open-meteo.com/v1/forecast?latitude=59.91&longitude=10.75&current=temperature_2m,relative_humidity_2m,wind_speed_10m&daily=precipitation_sum&past_days=1&forecast_days=1&timezone=auto" \
  -H "Accept: application/json"
```

### TypeScript

```ts
const response = await fetch(
  `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,relative_humidity_2m,wind_speed_10m&daily=precipitation_sum&past_days=1&forecast_days=1&timezone=auto`,
  {
    method: "GET",
    headers: {
      Accept: "application/json",
    },
  },
);
```

### Params

| Name            | Type      | Required | Description                                                                         |
| --------------- | --------- | -------- | ----------------------------------------------------------------------------------- |
| `latitude`      | `number`  | ✅       | Home latitude.                                                                      |
| `longitude`     | `number`  | ✅       | Home longitude.                                                                     |
| `current`       | `string`  | ❌       | CSV of current vars. App uses `temperature_2m,relative_humidity_2m,wind_speed_10m`. |
| `daily`         | `string`  | ❌       | CSV of daily vars. App uses `precipitation_sum`.                                    |
| `past_days`     | `integer` | ❌       | Days of history. App uses `1` (for 24h precip).                                     |
| `forecast_days` | `integer` | ❌       | Forecast horizon. App uses `1`.                                                     |
| `timezone`      | `string`  | ❌       | Timezone resolution. App uses `auto`.                                               |

```ts
interface ForecastParams {
  latitude: number;
  longitude: number;
  current?: string;
  daily?: string;
  past_days?: number;
  forecast_days?: number;
  timezone?: string;
}
```

### Payload

GET requests do not include a request body.

```ts
type ForecastPayload = never;
```

### Response (200)

```ts
interface ForecastResponse {
  latitude: number;
  longitude: number;
  timezone: string;
  current: {
    time: string;
    temperature_2m: number;
    relative_humidity_2m: number;
    wind_speed_10m: number;
  };
  daily: {
    time: string[];
    precipitation_sum: number[];
  };
}
```

Mapped to the app's `WeatherSnapshot` (`temperatureC`, `humidityPct`, `windKmh`, `precip24hMm`, `fetchedAt`).

</details>

<!--

> GEOCODING-SEARCH

-->

### /v1/search

<details id="weather-geocoding">
<summary>read more</summary>

```ts
const geocoding_search = "https://geocoding-api.open-meteo.com/v1/search";
```

Resolves a city name to coordinates. Note the **separate host** `geocoding-api.open-meteo.com` (not `api.open-meteo.com`).

**This is the app's user-location functionality.** The user types a city name in Settings (`_LocationDialog`, `settings_screen.dart:181`) → `WeatherApi.geocode()` hits this endpoint → the chosen `GeoPlace` is saved on `AppSettings` as `locationName` / `latitude` / `longitude` (`app_settings.dart:23-25`). `hasLocation` then gates `weatherProvider`, which calls `/v1/forecast` above. No device GPS is used.

> **Note:** `geolocator: ^14.0.3` is declared in `pubspec.yaml` but is **not called anywhere in `lib/`** — there is no GPS lookup wired up. Location is manual city search only. Either wire geolocator for "use my location," or drop the dependency.

### cURL (Placeholder Variables)

```bash
curl -X GET \
  "https://geocoding-api.open-meteo.com/v1/search?name=${NAME}&count=${COUNT}&language=${LANG}" \
  -H "Accept: application/json"
```

### cURL (Example Values)

```bash
curl -X GET \
  "https://geocoding-api.open-meteo.com/v1/search?name=Oslo&count=8&language=nb" \
  -H "Accept: application/json"
```

### TypeScript

```ts
const response = await fetch(
  `https://geocoding-api.open-meteo.com/v1/search?name=${name}&count=${count}&language=${language}`,
  {
    method: "GET",
    headers: {
      Accept: "application/json",
    },
  },
);
```

### Params

| Name       | Type      | Required | Description                                 |
| ---------- | --------- | -------- | ------------------------------------------- |
| `name`     | `string`  | ✅       | City/place search string.                   |
| `count`    | `integer` | ❌       | Max results. App uses `8`.                  |
| `language` | `string`  | ❌       | Result language. App uses `nb` (Norwegian). |

```ts
interface GeocodingParams {
  name: string;
  count?: number;
  language?: string;
}
```

### Payload

GET requests do not include a request body.

```ts
type GeocodingPayload = never;
```

### Response (200)

```ts
interface GeocodingResponse {
  results?: {
    name: string;
    latitude: number;
    longitude: number;
    admin1?: string;
    country?: string;
  }[];
}
```

Mapped to the app's `GeoPlace` (`name` = `"name, admin1, country"`, `latitude`, `longitude`).

</details>
