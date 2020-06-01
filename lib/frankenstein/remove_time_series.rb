module Frankenstein
	# Mix-in to add #remove to Prometheus metrics
	module RemoveTimeSeries
		# Remove a time series from a metric.
		#
		# @param labels [Hash<Symbol, String>] the label set to remove.
		#
		def remove(labels)
			@store.remove(labels)
		end

		# Mix-in to add #remove support to the default Synchronized metric store.
		module SynchronizedMetricStore
			# Remove a time series from the metric store.
			#
			# @private
			def remove(labels)
				@internal_store.delete(labels)
			end
		end
	end
end

Prometheus::Client::Metric.include(Frankenstein::RemoveTimeSeries)
Prometheus::Client::DataStores::Synchronized.const_get(:MetricStore).include(Frankenstein::RemoveTimeSeries::SynchronizedMetricStore)
