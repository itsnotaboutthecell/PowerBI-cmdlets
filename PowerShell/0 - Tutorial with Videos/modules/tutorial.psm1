function embedYoutube {
    param(
        $youtubeId
    )
    
    $htmlCode = @"
        <iframe 
            width="560" 
            height="315" 
            src="https://www.youtube.com/embed/$youtubeId" 
            frameborder="0" 
            allow="accelerometer; 
            autoplay; 
            encrypted-media; 
            gyroscope; 
            picture-in-picture" 
            allowfullscreen>
        </iframe>
"@
    return $htmlCode
}