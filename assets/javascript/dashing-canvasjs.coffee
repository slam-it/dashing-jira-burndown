class Dashing.Canvasjs extends Dashing.Widget

  chart: (id, data, title) ->
    new CanvasJS.Chart(id,
    {backgroundColor: "transparent",
    # title:{fontColor: "#999", text: title},
    legend: {fontColor: "#999"},
    axisY:{gridThickness: 0}
    data: data
    }
    ).render();
