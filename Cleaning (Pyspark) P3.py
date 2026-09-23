# Databricks notebook source
from pyspark.sql import functions as F

# COMMAND ----------

spark.sql("USE CATALOG campaign_offer_analytics")
spark.sql("USE SCHEMA dataset")

# COMMAND ----------

spend_df = spark.table("customer_spend_by_category")
acquired_df = spark.table("acquired_customers")

# COMMAND ----------

df = spend_df.join(acquired_df.select("customer_id", "channel", "card_product", "home_state", "age"),  on="customer_id", how="left")

# COMMAND ----------

df = df.withColumn(
    "total_spend",
    F.col("travel") + F.col("dining") + F.col("grocery") + F.col("online_shopping") +
    F.col("gas") + F.col("entertainment") + F.col("utilities_bills")
)
 
spend_categories = ["travel", "dining", "grocery", "online_shopping", "gas", "entertainment", "utilities_bills"]
 
for cat in spend_categories:
    df = df.withColumn(f"{cat}_pct", F.col(cat) / F.col("total_spend"))

# COMMAND ----------

feature_cols = [f"{cat}_pct" for cat in spend_categories]
 
clustering_features = df.select(
    ["customer_id", "true_persona", "channel", "card_product", "total_spend"] + feature_cols
)
 
clustering_features.write.format("delta").mode("overwrite").saveAsTable("persona_clustering_features")
 
print(f"Feature table created: {clustering_features.count()} rows")
display(clustering_features.limit(10))

# COMMAND ----------

