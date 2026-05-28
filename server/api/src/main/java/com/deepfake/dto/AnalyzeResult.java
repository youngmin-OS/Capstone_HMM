package com.deepfake.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public class AnalyzeResult {

    @JsonProperty("overall_risk")
    private int overallRisk;

    @JsonProperty("risk_label")
    private String riskLabel;

    @JsonProperty("lpips_risk")
    private double lpipsRisk;

    @JsonProperty("clip_risk")
    private double clipRisk;

    @JsonProperty("arc_risk")
    private double arcRisk;

    public int getOverallRisk() { return overallRisk; }
    public String getRiskLabel() { return riskLabel; }
    public double getLpipsRisk() { return lpipsRisk; }
    public double getClipRisk() { return clipRisk; }
    public double getArcRisk() { return arcRisk; }
}
