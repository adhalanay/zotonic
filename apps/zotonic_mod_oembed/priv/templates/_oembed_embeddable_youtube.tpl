<div class="embed-responsive" style="padding-top: {{ medium.oembed.height / medium.oembed.width * 100 }}%">
    {% if options.autoplay %}
        <iframe width="{{ medium.oembed.width }}" height="{{ medium.oembed.height }}"
                src="//youtube.com/embed/{{ medium.oembed.thumbnail_url|replace:".*/vi/([^/]*)/.*":"\\1" }}?autoplay=1"
                allow="autoplay" frameborder="0" allowfullscreen></iframe>
    {% else %}
        {{ medium.oembed.html }}
    {% endif %}
</div>
