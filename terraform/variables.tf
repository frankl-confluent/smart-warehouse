variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key (also referred as Cloud API ID)"
  type        = string
  default     = "BK2OUDBTOTSL2OKV"
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true
  default     = "cjWQKzia8XWnKHc3HnYbMjdzS2dSD2EDv7MKjfQuGZcWct5wLY/y45yDwOhkL0W7"
}
