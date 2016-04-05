# dashing-jira-widget
Jira burn-down widget for dashing

## Description

GitHub location: https://github.com/slam-it/dashing-jira-burndown

[Dashing](http://shopify.github.com/dashing) widget to display a [Jira](https://www.atlassian.com/software/jira) (greenhopper) burn-down of the active sprint

## Installation
##### 1. Import Canvasjs library
In `dashboards/layout.erb`, add this script tag:

`<script type="text/javascript" src="/assets/canvasjs.min.js"></script>`

before this script tag:

`<script type="text/javascript" src="/assets/application.js"></script>`

##### 2. Import Dashing.Canvasjs Widget

Put the files `canvasjs.min.js` and `dashing-canvasjs.coffee` files in the `/assets/javascripts` directory.
Then in `assets/javascripts/application.coffee`, add `#= require dashing-canvasjs` right after `#= require dashing.js` so it looks like this:

```
# dashing.js is located in the dashing framework
# It includes jquery & batman for you.
#= require dashing.js
#= require dashing-canvasjs
```

##### 3. Import Health widget

Put the files `burndown.coffee`, `burndown.html` and `burndown.scss` in the `/widget/burndown` directory and the file `burndown.rb` in the `/jobs` directory

## Job configuration

Required configuration:
* `HOST`: Url to your jira server, excluding the trailing slash (/).
* `USERNAME`: Username for a user with sufficient rights on your jira server.
* `PASSWORD`: Password for the user.
* `RAPID_VIEW_ID`: The rapid board view id.

## Dashboard configuration

Put the following in your dashboard.erb file to show the status:

```xml
<li data-row="1" data-col="1" data-sizex="2" data-sizey="1">
  <div data-id="burndown" data-view="Burndown" data-title="Sprint Burndown"></div>
</li>
```
